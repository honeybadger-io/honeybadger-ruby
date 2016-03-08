require 'pathname'
require 'delegate'
require 'logger'
require 'fileutils'
require 'openssl'

require 'honeybadger/version'
require 'honeybadger/logging'
require 'honeybadger/backend'
require 'honeybadger/config/defaults'
require 'honeybadger/util/http'
require 'honeybadger/logging'
require 'honeybadger/rack/request_hash'

module Honeybadger
  class Config
    extend Forwardable

    include Logging::Helper

    class ConfigError < StandardError; end

    autoload :Callbacks, 'honeybadger/config/callbacks'
    autoload :Env, 'honeybadger/config/env'
    autoload :Yaml, 'honeybadger/config/yaml'

    KEY_REPLACEMENT = Regexp.new('[^a-z\d_]', Regexp::IGNORECASE).freeze

    DOTTED_KEY = Regexp.new('\A([^\.]+)\.(.+)\z').freeze

    NOT_BLANK = Regexp.new('\S').freeze

    FEATURES = [:notices, :local_variables, :metrics, :traces].freeze

    MERGE_DEFAULT = [:'exceptions.ignore'].freeze

    OVERRIDE = {
      :'exceptions.ignore' => :'exceptions.ignore_only'
    }.freeze

    DEFAULT_REQUEST_HASH = {}.freeze

    def initialize(opts = {})
      l = opts.delete(:logger)

      @values = opts

      priority = {}
      priority.update(opts)
      load_config_from_disk {|yml| priority.update(yml) }
      priority.update(Env.new(ENV))
      update(merge_defaults!(priority))

      @logger = Logging::ConfigLogger.new(self, build_logger(l))
      Logging::BootLogger.instance.flush(@logger)

      @features = Hash[FEATURES.map{|f| [f, true] }]
    end

    def_delegators :@values, :update

    attr_reader :features

    def get(key)
      key = key.to_sym
      if OVERRIDE.has_key?(key) && @values.has_key?(OVERRIDE[key])
        @values[OVERRIDE[key]]
      elsif @values.has_key?(key)
        @values[key]
      else
        DEFAULTS[key]
      end
    end
    alias [] :get

    def set(key, value)
      @values[key] = value
    end
    alias []= :set

    def to_hash(defaults = false)
      hash = defaults ? DEFAULTS.merge(@values) : @values
      undotify_keys(hash.select {|k,v| DEFAULTS.has_key?(k) })
    end
    alias :to_h :to_hash

    def feature?(feature)
      !!features[feature.to_sym]
    end

    def traces?
      feature?(:traces) && !!self[:'traces.enabled']
    end

    def metrics?
      feature?(:metrics) && !!self[:'metrics.enabled']
    end

    def logger
      @logger || Logging::BootLogger.instance
    end

    def backend
      Backend.for((self[:backend] || default_backend).to_sym).new(self)
    end

    def dev?
      self[:env] && Array(self[:development_environments]).include?(self[:env])
    end

    def public?
      return true if self[:report_data]
      return false if self[:report_data] == false
      !self[:env] || !dev?
    end

    def default_backend
      if public?
        :server
      else
        :null
      end
    end

    def valid?
      self[:api_key].to_s =~ /\S/
    end

    def debug?
      !!self[:debug]
    end

    def log_debug?
      return debug? if self[:'logging.debug'].nil?
      !!self[:'logging.debug']
    end

    # Internal: Optional path to honeybadger.log log file. If nil, STDOUT will be used
    # instead.
    #
    # Returns the Pathname log path if a log path was specified.
    def log_path
      if self[:'logging.path'] && self[:'logging.path'] != 'STDOUT'
        locate_absolute_path(self[:'logging.path'], self[:root])
      end
    end

    # Internal: Path to honeybadger.yml configuration file; this should be the
    # root directory if no path was specified.
    #
    # Returns the Pathname configuration path.
    def config_path
      config_paths.first
    end

    def config_paths
      Array(ENV['HONEYBADGER_CONFIG_PATH'] || get(:'config.path')).map do |c|
        locate_absolute_path(c, self[:root])
      end
    end

    def ca_bundle_path
      if self[:'connection.system_ssl_cert_chain'] && File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
        OpenSSL::X509::DEFAULT_CERT_FILE
      else
        local_cert_path
      end
    end

    def local_cert_path
      File.expand_path(File.join('..', '..', '..', 'resources', 'ca-bundle.crt'), __FILE__)
    end

    def connection_port
      if self[:'connection.port']
        self[:'connection.port']
      elsif self[:'connection.secure']
        443
      else
        80
      end
    end

    def connection_protocol
      if self[:'connection.secure']
        'https'
      else
        'http'
      end
    end

    def request
      Thread.current[:__honeybadger_request]
    end

    def with_request(request, &block)
      Thread.current[:__honeybadger_request] = request
      yield
    ensure
      Thread.current[:__honeybadger_request] = nil
    end

    def max_queue_size
      self[:max_queue_size]
    end

    def request_hash
      return DEFAULT_REQUEST_HASH unless request
      Rack::RequestHash.new(request)
    end

    def params_filters
      self[:'request.filter_keys'] + rails_params_filters
    end

    def rails_params_filters
      request && request.env['action_dispatch.parameter_filter'] or []
    end

    def excluded_request_keys
      [].tap do |keys|
        keys << :session  if self[:'request.disable_session']
        keys << :params   if self[:'request.disable_params']
        keys << :cgi_data if self[:'request.disable_environment']
        keys << :url      if self[:'request.disable_url']
      end
    end

    def write
      path = config_path

      if path.exist?
        raise ConfigError, "The configuration file #{path} already exists."
      elsif !path.dirname.writable?
        raise ConfigError, "The configuration path #{path.dirname} is not writable."
      end

      File.open(path, 'w+') do |file|
        file.write(<<-CONFIG)
---
api_key: '#{self[:api_key]}'
                   CONFIG
      end
    end

    def log_level(key = :'logging.level')
      case self[key].to_s
      when /\A(0|debug)\z/i then Logger::DEBUG
      when /\A(1|info)\z/i  then Logger::INFO
      when /\A(2|warn)\z/i  then Logger::WARN
      when /\A(3|error)\z/i then Logger::ERROR
      else
        Logger::INFO
      end
    end

    def load_plugin?(name)
      return false if includes_token?(self[:'plugins.skip'], name)
      return true unless self[:plugins].kind_of?(Array)
      includes_token?(self[:plugins], name)
    end

    def ping
      if result = send_ping
        @features = symbolize_keys(result['features']) if result['features']
        return true
      end

      false
    end

    def framework
      if self[:framework] =~ NOT_BLANK
        self[:framework].to_sym
      elsif defined?(::Rails::VERSION) && ::Rails::VERSION::STRING > '3.0'
        :rails
      elsif defined?(::Sinatra::VERSION)
        :sinatra
      elsif defined?(::Rack.release)
        :rack
      else
        :ruby
      end
    end

    def framework_name
      case framework
      when :rails then "Rails #{::Rails::VERSION::STRING}"
      when :sinatra then "Sinatra #{::Sinatra::VERSION}"
      when :rack then "Rack #{::Rack.release}"
      else
        "Ruby #{RUBY_VERSION}"
      end
    end

    # Internal: Match the project root.
    #
    # Returns Regexp matching the project root in a file string.
    def root_regexp
      return @root_regexp if @root_regexp
      return nil if @no_root

      root = get(:root).to_s
      @no_root = true and return nil unless root =~ NOT_BLANK

      @root_regexp = Regexp.new("^#{ Regexp.escape(root) }")
    end

    private

    # Internal: Does collection include the String value or Symbol value?
    #
    # obj - The Array object, if present.
    # value - The value which may exist within Array obj.
    #
    # Returns true or false.
    def includes_token?(obj, value)
      return false unless obj.kind_of?(Array)
      obj.map(&:to_sym).include?(value.to_sym)
    end

    def ping_payload
      {
        version: VERSION,
        framework: framework_name,
        environment: self[:env],
        hostname: self[:hostname],
        config: to_hash
      }
    end

    def send_ping
      payload = ping_payload
      debug { sprintf('ping payload=%s', payload.to_json.dump) }
      response = backend.notify(:ping, payload)
      if response.success?
        debug { sprintf('ping response=%s', response.body.dump) }
        JSON.parse(response.body)
      else
        warn do
          msg = sprintf('ping failure code=%s', response.code)
          msg << sprintf(' message=%s', response.message.dump) if response.message =~ NOT_BLANK
          msg
        end
        nil
      end
    end

    def locate_absolute_path(path, root)
      path = Pathname.new(path.to_s)
      if path.absolute?
        path
      else
        Pathname.new(root.to_s).join(path.to_s)
      end
    end

    def build_logger(default = nil)
      if path = log_path
        FileUtils.mkdir_p(path.dirname) unless path.dirname.writable?
        Logger.new(path).tap do |logger|
          logger.level = log_level
          logger.formatter = Logger::Formatter.new
        end
      elsif self[:'logging.path'] != 'STDOUT' && default
        default
      else
        logger = Logger.new($stdout)
        logger.level = log_level
        logger.formatter = lambda do |severity, datetime, progname, msg|
          "#{msg}\n"
        end
        Logging::FormattedLogger.new(logger)
      end
    end

    def load_config_from_disk
      if (path = config_paths.find(&:exist?)) && path.file?
        Yaml.new(path, self[:env]).tap do |yml|
          yield(yml) if block_given?
        end
      end
    rescue ConfigError => e
      error("error while loading config from disk: #{e}")
      nil
    rescue StandardError => e
      error {
        msg = "error while loading config from disk class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
      nil
    end

    def undotify_keys(hash)
      {}.tap do |new_hash|
        hash.each_pair do |k,v|
          if k.to_s =~ DOTTED_KEY
            new_hash[$1] ||= {}
            new_hash[$1] = undotify_keys(new_hash[$1].merge({$2 => v}))
          else
            new_hash[k] = v
          end
        end
      end
    end

    def symbolize_keys(hash)
      Hash[hash.map {|k,v| [k.to_sym, v] }]
    end

    # Internal: Merges supplied config options with defaults.
    #
    # config - The Hash config options to merge.
    #
    # Returns the updated Hash config with merged values.
    def merge_defaults!(config)
      MERGE_DEFAULT.each do |option|
        if config[option].kind_of?(Array)
          config[option] = (DEFAULTS[option] | config[option])
        end
      end

      config
    end
  end
end
