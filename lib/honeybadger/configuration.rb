require 'socket'

module Honeybadger
  class Configuration
    OPTIONS = [:api_key, :backtrace_filters, :development_environments, :environment_name,
               :host, :http_open_timeout, :http_read_timeout, :ignore, :ignore_by_filters,
               :ignore_user_agent, :notifier_name, :notifier_url, :notifier_version,
               :params_filters, :project_root, :port, :protocol, :proxy_host, :proxy_pass,
               :proxy_port, :proxy_user, :secure, :use_system_ssl_cert_chain, :framework,
               :user_information, :feedback, :rescue_rake_exceptions, :source_extract_radius,
               :send_request_session, :debug, :fingerprint, :hostname, :features, :metrics,
               :log_exception_on_send_failure, :send_local_variables, :traces,
               :trace_threshold, :unwrap_exceptions, :delayed_job_attempt_threshold].freeze

    # The API key for your project, found on the project edit form.
    attr_accessor :api_key

    # The host to connect to (defaults to honeybadger.io).
    attr_accessor :host

    # The port on which your Honeybadger server runs (defaults to 443 for secure
    # connections, 80 for insecure connections).
    attr_accessor :port

    # +true+ for https connections, +false+ for http connections.
    attr_accessor :secure

    # +true+ to use whatever CAs OpenSSL has installed on your system. +false+ to use the ca-bundle.crt file included in Honeybadger itself (reccomended and default)
    attr_accessor :use_system_ssl_cert_chain

    # The HTTP open timeout in seconds (defaults to 2).
    attr_accessor :http_open_timeout

    # The HTTP read timeout in seconds (defaults to 5).
    attr_accessor :http_read_timeout

    # The hostname of your proxy server (if using a proxy)
    attr_accessor :proxy_host

    # The port of your proxy server (if using a proxy)
    attr_accessor :proxy_port

    # The username to use when logging into your proxy server (if using a proxy)
    attr_accessor :proxy_user

    # The password to use when logging into your proxy server (if using a proxy)
    attr_accessor :proxy_pass

    # A list of parameters that should be filtered out of what is sent to Honeybadger.
    # By default, all "password" attributes will have their contents replaced.
    attr_reader :params_filters

    # A list of filters for cleaning and pruning the backtrace. See #filter_backtrace.
    attr_reader :backtrace_filters

    # A list of filters for ignoring exceptions. See #ignore_by_filter.
    attr_reader :ignore_by_filters

    # A list of exception classes to ignore. The array can be appended to.
    attr_reader :ignore

    # A list of user agents that are being ignored. The array can be appended to.
    attr_reader :ignore_user_agent

    # Traces must have a duration greater than this (in ms) to be recorded
    attr_reader :trace_threshold

    # A list of environments in which notifications should not be sent.
    attr_accessor :development_environments

    # The name of the environment the application is running in
    attr_accessor :environment_name

    # The path to the project in which the error occurred, such as the Rails.root
    attr_accessor :project_root

    # The name of the notifier library being used to send notifications (such as "Honeybadger Notifier")
    attr_accessor :notifier_name

    # The version of the notifier library being used to send notifications (such as "1.0.2")
    attr_accessor :notifier_version

    # The url of the notifier library being used to send notifications
    attr_accessor :notifier_url

    # The logger used by Honeybadger
    attr_accessor :logger

    # The text that the placeholder is replaced with. {{error_id}} is the actual error number.
    attr_accessor :user_information

    # Display user feedback form when configured?
    attr_accessor :feedback

    # The framework Honeybadger is configured to use.
    attr_accessor :framework

    # Should Honeybadger catch exceptions from Rake tasks?
    # (boolean or nil; set to nil to catch exceptions when rake isn't running from a terminal; default is nil)
    attr_accessor :rescue_rake_exceptions

    # The radius around trace line to include in source excerpt
    attr_accessor :source_extract_radius

    # +true+ to send session data, +false+ to exclude
    attr_accessor :send_request_session

    # +true+ to send local variables, +false+ to exclude
    attr_accessor :send_local_variables

    # +true+ to unwrap exceptions
    attr_accessor :unwrap_exceptions

    # +true+ to log extra debug info, +false+ to suppress
    attr_accessor :debug

    # +true+ to log the original exception on send failure, +false+ to suppress
    attr_accessor :log_exception_on_send_failure

    # A Proc object used to send notices asynchronously
    attr_writer :async

    # A Proc object used to generate optional fingerprint
    attr_writer :fingerprint

    # Override the hostname of the local server (optional)
    attr_accessor :hostname

    # Send metrics?
    attr_accessor :metrics

    # Send traces?
    attr_accessor :traces

    # Which features the API says we have
    attr_accessor :features

    # Do not notify unless Delayed Job attempts reaches or exceeds this value
    attr_accessor :delayed_job_attempt_threshold

    DEFAULT_PARAMS_FILTERS = %w(password password_confirmation).freeze

    DEFAULT_BACKTRACE_FILTERS = [
      lambda { |line|
        if defined?(Honeybadger.configuration.project_root) && Honeybadger.configuration.project_root.to_s != ''
          line.sub(/#{Honeybadger.configuration.project_root}/, "[PROJECT_ROOT]")
        else
          line
        end
      },
      lambda { |line| line.gsub(/^\.\//, "") },
      lambda { |line|
        if defined?(Gem)
          Gem.path.inject(line) do |line, path|
            line.gsub(/#{path}/, "[GEM_ROOT]")
          end
        end
      },
      lambda { |line| line if line !~ %r{lib/honeybadger} }
    ].freeze

    IGNORE_DEFAULT = ['ActiveRecord::RecordNotFound',
                      'ActionController::RoutingError',
                      'ActionController::InvalidAuthenticityToken',
                      'CGI::Session::CookieStore::TamperedWithCookie',
                      'ActionController::UnknownAction',
                      'AbstractController::ActionNotFound',
                      'Mongoid::Errors::DocumentNotFound',
                      'Sinatra::NotFound',
                      'ActionController::UnknownFormat']

    alias_method :secure?, :secure
    alias_method :use_system_ssl_cert_chain?, :use_system_ssl_cert_chain

    def initialize
      @api_key                       = ENV['HONEYBADGER_API_KEY']
      @secure                        = true
      @use_system_ssl_cert_chain     = false
      @host                          = 'api.honeybadger.io'
      @http_open_timeout             = 2
      @http_read_timeout             = 5
      @params_filters                = DEFAULT_PARAMS_FILTERS.dup
      @backtrace_filters             = DEFAULT_BACKTRACE_FILTERS.dup
      @ignore_by_filters             = []
      @ignore                        = IGNORE_DEFAULT.dup
      @ignore_user_agent             = []
      @development_environments      = %w(development test cucumber)
      @notifier_name                 = 'Honeybadger Notifier'
      @notifier_version              = VERSION
      @notifier_url                  = 'https://github.com/honeybadger-io/honeybadger-ruby'
      @framework                     = 'Standalone'
      @user_information              = 'Honeybadger Error {{error_id}}'
      @rescue_rake_exceptions        = nil
      @source_extract_radius         = 2
      @send_request_session          = true
      @send_local_variables          = false
      @debug                         = false
      @log_exception_on_send_failure = false
      @hostname                      = Socket.gethostname
      @metrics                       = true
      @features                      = {'notices' => true, 'local_variables' => true}
      @traces                        = true
      @limit                         = nil
      @feedback                      = true
      @trace_threshold               = 2000
      @unwrap_exceptions             = true
      @delayed_job_attempt_threshold = 0
    end

    # Public: Takes a block and adds it to the list of backtrace filters. When
    # the filters run, the block will be handed each line of the backtrace and
    # can modify it as necessary.
    #
    # &block - The new backtrace filter.
    #
    # Examples:
    #
    #    config.filter_bracktrace do |line|
    #      line.gsub(/^#{Rails.root}/, "[Rails.root]")
    #    end
    #
    # Yields a line in the backtrace.
    def filter_backtrace(&block)
      self.backtrace_filters << block
    end

    # Public: Takes a block and adds it to the list of ignore filters. When
    # the filters run, the block will be handed the exception.
    #
    # &block - The new ignore filter
    #          If the block returns true the exception will be ignored, otherwise it
    #          will be processed by honeybadger.
    #
    # Examples:
    #
    #   config.ignore_by_filter do |exception_data|
    #     true if exception_data[:error_class] == "RuntimeError"
    #   end
    #
    # Yields the the exception data given to Honeybadger.notify
    def ignore_by_filter(&block)
      self.ignore_by_filters << block
    end

    # Public: Overrides the list of default ignored errors.
    #
    # names - A list of exceptions to ignore.
    #
    # Returns nothing
    def ignore_only=(names)
      @ignore = [names].flatten
    end

    # Public: Overrides the list of default ignored user agents
    #
    # names - A list of user agents to ignore
    #
    # Returns nothing
    def ignore_user_agent_only=(names)
      @ignore_user_agent = [names].flatten
    end

    def trace_threshold=(threshold)
      @trace_threshold = [threshold, 1000].max
    end

    # Public: Allows config options to be read like a hash
    #
    # option - Key for a given attribute
    #
    # Returns value of requested attribute
    def [](option)
      send(option)
    end

    # Public
    # Returns a hash of all configurable options
    def to_hash
      OPTIONS.inject({}) do |hash, option|
        hash[option.to_sym] = self.send(option)
        hash
      end
    end

    # Public
    #
    # hash - A set of configuration options that will take precedence over the defaults
    #
    # Returns a hash of all configurable options merged with +hash+
    def merge(hash)
      to_hash.merge(hash)
    end

    # Public: Determines if the notifier will send notices.
    #
    # Returns true if allowed to talk to API, false otherwise.
    def public?
      api_key =~ /\S/ && !development_environments.include?(environment_name)
    end

    # Public: Determines whether to send metrics
    #
    def metrics?
      public? && @metrics
    end

    # Public: Determines whether to send traces
    #
    def traces?
      public? && @traces
    end

    # Public: Configure async delivery
    #
    # block - An optional block containing an async handler
    #
    # Examples
    #
    #   config.async = Proc.new { |notice| Thread.new { Honeybadger.sender.send_to_honeybadger(notice) } }
    #
    #   config.async do |notice|
    #     Thread.new { Honeybadger.sender.send_to_honeybadger(notice) }
    #   end
    #
    # Returns configured async handler (should respond to #call(notice))
    def async
      @async = Proc.new if block_given?
      @async
    end
    alias :async? :async

    # Public: Generate custom fingerprint (optional)
    #
    # block - An optional block returning object responding to #to_s
    #
    # Examples
    #
    #   config.fingerprint = Proc.new { |notice| ... }
    #
    #   config.fingerprint do |notice|
    #     [notice[:error_class], notice[:component], notice[:backtrace].to_s].join(':')
    #   end
    #
    # Returns configured fingerprint generator (should respond to #call(notice))
    def fingerprint
      @fingerprint = Proc.new if block_given?
      @fingerprint
    end

    def port
      @port || default_port
    end

    # Public: Determines whether protocol should be "http" or "https".
    #
    # Returns 'http' if you've set secure to false in
    # configuration, and 'https' otherwise.
    def protocol
      if secure?
        'https'
      else
        'http'
      end
    end

    def ca_bundle_path
      if use_system_ssl_cert_chain? && File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
        OpenSSL::X509::DEFAULT_CERT_FILE
      else
        local_cert_path # ca-bundle.crt built from source, see resources/README.md
      end
    end

    def local_cert_path
      File.expand_path(File.join("..", "..", "..", "resources", "ca-bundle.crt"), __FILE__)
    end

    # Stub deprecated current_user_method configuration option
    # This should be removed completely once everyone has updated to > 1.2
    def current_user_method=(null) ; end

    private

    # Private: Determines what port should we use for sending notices.
    #
    # Returns 443 if you've set secure to true in your
    # configuration, and 80 otherwise.
    def default_port
      if secure?
        443
      else
        80
      end
    end
  end
end

