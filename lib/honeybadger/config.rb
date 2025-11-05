require "pathname"
require "delegate"
require "logger"
require "fileutils"
require "openssl"

require "honeybadger/version"
require "honeybadger/logging"
require "honeybadger/backend"
require "honeybadger/config/defaults"
require "honeybadger/util/http"
require "honeybadger/util/revision"

module Honeybadger
  # @api private
  # The Config class is used to manage Honeybadger's initialization and
  # configuration.
  class Config
    extend Forwardable

    include Logging::Helper

    class ConfigError < StandardError; end

    # Config subclasses have circular dependencies, so they must be loaded
    # after constants are defined.
    autoload :Env, "honeybadger/config/env"
    autoload :Yaml, "honeybadger/config/yaml"
    autoload :Ruby, "honeybadger/config/ruby"

    KEY_REPLACEMENT = Regexp.new('[^a-z\d_]', Regexp::IGNORECASE).freeze

    DOTTED_KEY = Regexp.new('\A([^\.]+)\.(.+)\z').freeze

    NOT_BLANK = Regexp.new('\S').freeze

    IVARS = [:@ruby, :@env, :@yaml, :@framework].freeze

    DEPRECATED_OPTION_ALIASES = {
      :"rails.insights.events" => :"rails.insights.active_support_events"
    }.freeze

    def initialize(opts = {})
      @deprecated_option_warnings = {}
      @ruby = {}.freeze
      @env = {}.freeze
      @yaml = {}.freeze
      @framework = {}.freeze

      processed_opts = opts.is_a?(Hash) ? opts.dup : opts
      if processed_opts.is_a?(Hash)
        apply_deprecated_options!(processed_opts, source_label: "Ruby options")
      end

      @ruby = processed_opts.freeze
    end

    attr_accessor :ruby, :env, :yaml, :framework

    # Called by framework (see lib/honeybadger/init/) at the point of
    # initialization. This is not required for the notifier to work (i.e. with
    # `require 'honeybadger/ruby'`).
    def init!(opts = {}, env = ENV)
      load!(framework: opts, env: env)

      init_logging!
      init_backend!

      logger.debug(sprintf("Initializing Honeybadger Error Tracker for Ruby. Ship it! version=%s framework=%s", Honeybadger::VERSION, detected_framework))
      logger.warn("Development mode is enabled. Data will not be reported until you deploy your app.") if warn_development?

      self
    end

    def load!(framework: {}, env: ENV)
      return self if @loaded
      framework_opts = framework.is_a?(Hash) ? framework.dup : framework
      if framework_opts.is_a?(Hash)
        apply_deprecated_options!(framework_opts, source_label: "framework configuration")
        self.framework = framework_opts.freeze
      else
        self.framework = framework.freeze
      end

      env_opts = Env.new(env)
      apply_deprecated_options!(env_opts, source_label: lambda { |old_key, _new_key|
        "environment variable #{env_var_name_for(old_key)}"
      })
      self.env = env_opts.freeze

      load_config_from_disk do |yaml|
        apply_deprecated_options!(yaml, source_label: "YAML configuration")
        self.yaml = yaml.freeze
      end
      detect_revision!
      @loaded = true
      self
    end

    def configure
      new_ruby = Ruby.new(self)
      yield(new_ruby)
      apply_deprecated_options!(new_ruby.to_hash, source_label: "Ruby configuration block")
      self.ruby = ruby.merge(new_ruby).freeze
      @logger = @backend = nil
      self
    end

    def backtrace_filter(&block)
      if block_given?
        warn("DEPRECATED: backtrace_filter is deprecated. Please use before_notify instead. See https://docs.honeybadger.io/ruby/support/v4-upgrade#backtrace_filter")
        self[:backtrace_filter] = block
      end

      self[:backtrace_filter]
    end

    def before_notify_hooks
      (ruby[:before_notify] || []).clone
    end

    def before_event_hooks
      (ruby[:before_event] || []).clone
    end

    def exception_filter(&block)
      if block_given?
        warn("DEPRECATED: exception_filter is deprecated. Please use before_notify instead. See https://docs.honeybadger.io/ruby/support/v4-upgrade#exception_filter")
        self[:exception_filter] = block
      end

      self[:exception_filter]
    end

    def exception_fingerprint(&block)
      if block_given?
        warn("DEPRECATED: exception_fingerprint is deprecated. Please use before_notify instead. See https://docs.honeybadger.io/ruby/support/v4-upgrade#exception_fingerprint")
        self[:exception_fingerprint] = block
      end

      self[:exception_fingerprint]
    end

    def get(key)
      key = canonical_option(key)
      IVARS.each do |var|
        source = instance_variable_get(var)
        if source.has_key?(key)
          return source[key]
        end
      end

      DEFAULTS[key]
    end
    alias_method :[], :get

    def set(key, value)
      normalized_key = normalize_option_key(key)
      canonical_key = canonical_option(normalized_key)
      if canonical_key != normalized_key
        warn_deprecated_option(normalized_key, canonical_key, "Ruby runtime configuration")
      end
      self.ruby = ruby.merge(canonical_key => value).freeze
      @logger = @backend = nil
    end
    alias_method :[]=, :set

    def to_hash(defaults = false)
      hash = [:@ruby, :@env, :@yaml, :@framework].reverse.reduce({}) do |a, e|
        a.merge!(instance_variable_get(e))
      end

      hash = DEFAULTS.merge(hash) if defaults

      undotify_keys(hash.select { |k, v| DEFAULTS.has_key?(k) })
    end
    alias_method :to_h, :to_hash

    # Internal Helpers

    def logger
      init_logging! unless @logger
      @logger
    end

    def backend
      init_backend! unless @backend
      @backend
    end

    def backend=(backend)
      set(:backend, backend)
      @backend = nil
    end

    def dev?
      self[:env] && Array(self[:development_environments]).include?(self[:env])
    end

    def warn_development?
      dev? && backend.is_a?(Backend::Null)
    end

    def public?
      return true if self[:report_data]
      return false if self[:report_data] == false
      !self[:env] || !dev?
    end

    def debug?
      !!self[:debug]
    end

    def log_debug?
      return debug? if self[:"logging.debug"].nil?
      !!self[:"logging.debug"]
    end

    def ignored_classes
      ignore_only = get(:"exceptions.ignore_only")
      return ignore_only if ignore_only
      return DEFAULTS[:"exceptions.ignore"] unless (ignore = get(:"exceptions.ignore"))

      DEFAULTS[:"exceptions.ignore"] | Array(ignore)
    end

    def raw_ignored_events
      ignore_only = get(:"events.ignore_only")
      return ignore_only if ignore_only
      return DEFAULTS[:"events.ignore"] unless (ignore = get(:"events.ignore"))

      DEFAULTS[:"events.ignore"] | Array(ignore)
    end

    def ignored_events
      @ignored_events ||= raw_ignored_events.map do |check|
        if check.is_a?(String) || check.is_a?(Regexp)
          {[:event_type] => check}
        elsif check.is_a?(Hash)
          flat_hash(check).transform_keys! { |key_array| key_array.map(&:to_sym) }
        end
      end.compact
    end

    def ca_bundle_path
      if self[:"connection.system_ssl_cert_chain"] && File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
        OpenSSL::X509::DEFAULT_CERT_FILE
      elsif self[:"connection.ssl_ca_bundle_path"]
        self[:"connection.ssl_ca_bundle_path"]
      else
        local_cert_path
      end
    end

    def local_cert_path
      File.expand_path(File.join("..", "..", "..", "resources", "ca-bundle.crt"), __FILE__)
    end

    def connection_port
      if self[:"connection.port"]
        self[:"connection.port"]
      elsif self[:"connection.secure"]
        443
      else
        80
      end
    end

    def connection_protocol
      if self[:"connection.secure"]
        "https"
      else
        "http"
      end
    end

    def max_queue_size
      self[:max_queue_size]
    end

    def events_max_queue_size
      self[:"events.max_queue_size"]
    end

    def events_batch_size
      self[:"events.batch_size"]
    end

    def events_timeout
      self[:"events.timeout"]
    end

    def params_filters
      Array(self[:"request.filter_keys"])
    end

    def excluded_request_keys
      [].tap do |keys|
        keys << :session if self[:"request.disable_session"]
        keys << :params if self[:"request.disable_params"]
        keys << :cgi_data if self[:"request.disable_environment"]
        keys << :url if self[:"request.disable_url"]
      end
    end

    def log_level(key = :"logging.level")
      case self[key].to_s
      when /\A(0|debug)\z/i then Logger::DEBUG
      when /\A(1|info)\z/i then Logger::INFO
      when /\A(2|warn)\z/i then Logger::WARN
      when /\A(3|error)\z/i then Logger::ERROR
      else
        Logger::INFO
      end
    end

    def load_plugin?(name)
      return false if includes_token?(self[:skipped_plugins], name)
      return true unless self[:plugins].is_a?(Array)
      includes_token?(self[:plugins], name)
    end

    def insights_enabled?
      public? && !!self[:"insights.enabled"]
    end

    def cluster_collection?(name)
      return false unless insights_enabled?
      return true if self[:"#{name}.insights.cluster_collection"].nil?
      !!self[:"#{name}.insights.cluster_collection"]
    end

    def collection_interval(name)
      return nil unless insights_enabled?
      self[:"#{name}.insights.collection_interval"]
    end

    def load_plugin_insights?(name)
      return false unless insights_enabled?
      return true if self[:"#{name}.insights.enabled"].nil?
      !!self[:"#{name}.insights.enabled"]
    end

    def load_plugin_insights_events?(name)
      return false unless insights_enabled?
      return false unless load_plugin_insights?(name)
      return true if self[:"#{name}.insights.events"].nil?
      !!self[:"#{name}.insights.events"]
    end

    def load_plugin_insights_metrics?(name)
      return false unless insights_enabled?
      return false unless load_plugin_insights?(name)
      return true if self[:"#{name}.insights.metrics"].nil?
      !!self[:"#{name}.insights.metrics"]
    end

    def load_plugin_insights_structured_events?(name)
      return false unless insights_enabled?
      return false unless load_plugin_insights?(name)
      return true if self[:"#{name}.insights.structured_events"].nil?
      !!self[:"#{name}.insights.structured_events"]
    end

    def load_plugin_insights_active_support_events?(name)
      return false unless insights_enabled?
      return false unless load_plugin_insights?(name)
      return true if self[:"#{name}.insights.active_support_events"].nil?
      !!self[:"#{name}.insights.active_support_events"]
    end

    def root_regexp
      return @root_regexp if @root_regexp
      return nil if @no_root

      root = get(:root).to_s
      @no_root = true and return nil unless NOT_BLANK.match?(root)

      @root_regexp = Regexp.new("^#{Regexp.escape(root)}")
    end

    def detected_framework
      if NOT_BLANK.match?(self[:framework])
        self[:framework].to_sym
      elsif defined?(::Rails::VERSION) && ::Rails::VERSION::STRING > "3.0"
        :rails
      elsif defined?(::Sinatra::VERSION)
        :sinatra
      elsif defined?(::Hanami::VERSION) && ::Hanami::VERSION >= "2.0"
        :hanami
      elsif defined?(::Rack.release)
        :rack
      else
        :ruby
      end
    end

    def framework_name
      case detected_framework
      when :rails then "Rails #{::Rails::VERSION::STRING}"
      when :sinatra then "Sinatra #{::Sinatra::VERSION}"
      when :hanami then "Hanami #{::Hanami::VERSION}"
      when :rack then "Rack #{::Rack.release}"
      else
        "Ruby #{RUBY_VERSION}"
      end
    end

    private

    def detect_revision!
      return if self[:revision]
      set(:revision, Util::Revision.detect(self[:root]))
    end

    def log_path
      return if log_stdout?
      return if !self[:"logging.path"]
      locate_absolute_path(self[:"logging.path"], self[:root])
    end

    def config_path
      config_paths.first
    end

    def config_paths
      Array(ENV["HONEYBADGER_CONFIG_PATH"] || get(:"config.path")).map do |c|
        locate_absolute_path(c, self[:root])
      end
    end

    def default_backend
      return Backend::Server.new(self) if public?
      Backend::Null.new(self)
    end

    def init_backend!
      if self[:backend].is_a?(String) || self[:backend].is_a?(Symbol)
        @backend = Backend.for(self[:backend].to_sym).new(self)
        return
      end

      if ruby[:backend].respond_to?(:notify)
        @backend = ruby[:backend]
        return
      end

      if ruby[:backend]
        logger.warn(sprintf("Unknown backend: %p; default will be used. Backend must respond to #notify", self[:backend]))
      end

      @backend = default_backend
    end

    def build_stdout_logger
      logger = Logger.new($stdout)
      logger.formatter = lambda do |severity, datetime, progname, msg|
        "#{msg}\n"
      end
      logger.level = log_level
      Logging::FormattedLogger.new(logger)
    end

    def build_file_logger(path)
      Logger.new(path).tap do |logger|
        logger.level = log_level
        logger.formatter = Logger::Formatter.new
      end
    end

    def log_stdout?
      self[:"logging.path"] && self[:"logging.path"].to_s.downcase == "stdout"
    end

    def build_logger
      return ruby[:logger] if ruby[:logger]

      return build_stdout_logger if log_stdout?

      if (path = log_path)
        FileUtils.mkdir_p(path.dirname) unless path.dirname.writable?
        return build_file_logger(path)
      end

      return framework[:logger] if framework[:logger]

      Logger.new(nil)
    end

    def init_logging!
      @logger = Logging::ConfigLogger.new(self, build_logger)
    end

    # Takes an Array and a value and returns true if the value exists in the
    # array in String or Symbol form, otherwise false.
    def includes_token?(obj, value)
      return false unless obj.is_a?(Array)
      obj.map(&:to_sym).include?(value.to_sym)
    end

    def locate_absolute_path(path, root)
      path = Pathname.new(path.to_s)
      if path.absolute?
        path
      else
        Pathname.new(root.to_s).join(path.to_s)
      end
    end

    def apply_deprecated_options!(hash, source_label:)
      return hash unless hash.is_a?(Hash)

      DEPRECATED_OPTION_ALIASES.each do |old_key, new_key|
        key_variant = if hash.has_key?(old_key)
          old_key
        elsif hash.has_key?(old_key.to_s)
          old_key.to_s
        end
        next unless key_variant

        value = hash.delete(key_variant)
        label = source_label.respond_to?(:call) ? source_label.call(old_key, new_key) : source_label
        warn_deprecated_option(old_key, new_key, label)
        hash[new_key] = value unless hash.has_key?(new_key)
      end

      hash
    end

    def normalize_option_key(key)
      return key if key.is_a?(Symbol)
      return key.to_sym if key.respond_to?(:to_sym)

      key
    end

    def canonical_option(key)
      normalized = normalize_option_key(key)
      DEPRECATED_OPTION_ALIASES.fetch(normalized, normalized)
    end

    def warn_deprecated_option(old_key, new_key, source_label = nil)
      @deprecated_option_warnings ||= {}
      cache_key = [old_key, source_label]
      return if @deprecated_option_warnings[cache_key]

      @deprecated_option_warnings[cache_key] = true

      message = "DEPRECATED: The `#{old_key}` configuration option is deprecated; use `#{new_key}` instead."
      message = "#{message} (configured via #{source_label})" if source_label
      logger.warn(message)
    end

    def env_var_name_for(option_key)
      "HONEYBADGER_" + option_key.to_s.upcase.gsub(KEY_REPLACEMENT, "_")
    end

    def load_config_from_disk
      if (path = config_paths.find(&:exist?)) && path.file?
        Yaml.new(path, self[:env]).tap do |yml|
          yield(yml) if block_given?
        end
      end
    end

    def undotify_keys(hash)
      {}.tap do |new_hash|
        hash.each_pair do |k, v|
          if k.to_s =~ DOTTED_KEY
            new_hash[$1] ||= {}
            new_hash[$1] = undotify_keys(new_hash[$1].merge({$2 => v}))
          else
            new_hash[k.to_s] = v
          end
        end
      end
    end

    # Converts a nested hash into a single layer where keys become arrays:
    # ex: > flat_hash({ :nested => { :hash => "value" }})
    #     > { [:nested, :hash] => "value" }
    def flat_hash(h, f = [], g = {})
      return g.update({f => h}) unless h.is_a? Hash
      h.each { |k, r| flat_hash(r, f + [k], g) }
      g
    end
  end
end
