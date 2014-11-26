require 'net/http'
require 'net/https'
require 'json'
require 'digest'
require 'logger'

require 'honeybadger/dependency'
require 'honeybadger/configuration'
require 'honeybadger/backtrace'
require 'honeybadger/notice'
require 'honeybadger/rack'
require 'honeybadger/sender'
require 'honeybadger/stats'
require 'honeybadger/user_informer'
require 'honeybadger/user_feedback'
require 'honeybadger/integrations'

require 'honeybadger/railtie' if defined?(Rails::Railtie)
require 'honeybadger/monitor'

module Honeybadger
  VERSION = '1.16.6'.freeze
  LOG_PREFIX = "** [Honeybadger] ".freeze

  HEADERS = {
    'Content-type' => 'application/json',
    'Content-Encoding' => 'deflate',
    'Accept'       => 'text/json, application/json',
    'User-Agent'   => "HB-Ruby #{VERSION}; #{RUBY_VERSION}; #{RUBY_PLATFORM}"
  }.freeze

  class << self
    # The sender object is responsible for delivering formatted data to the
    # Honeybadger server. Must respond to #send_to_honeybadger. See Honeybadger::Sender.
    attr_accessor :sender

    # A Honeybadger configuration object. Must act like a hash and return sensible
    # values for all Honeybadger configuration options. See Honeybadger::Configuration.
    attr_writer :configuration

    # Tell the log that the Notifier is good to go
    def report_ready
      write_verbose_log("Notifier #{VERSION} ready to catch errors", :info)
    end

    # Prints out the environment info to the log for debugging help
    def report_environment_info
      write_verbose_log("Environment Info: #{environment_info}")
    end

    # Prints out the response body from Honeybadger for debugging help
    def report_response_body(response)
      write_verbose_log("Response from Honeybadger: \n#{response}")
    end

    # Returns the Ruby version, Rails version, and current Rails environment
    def environment_info
      info = "[Ruby: #{RUBY_VERSION}]"
      info << " [#{configuration.framework}]" if configuration.framework
      info << " [Env: #{configuration.environment_name}]" if configuration.environment_name
    end

    # Writes out the given message to the #logger
    def write_verbose_log(message, level = Honeybadger.configuration.debug ? :info : :debug)
      logger.send(level, LOG_PREFIX + message) if logger
    end

    # Look for the Rails logger currently defined
    def logger
      self.configuration.logger
    end

    # Public: Call this method to modify defaults in your initializers.
    #
    # Examples:
    #
    #   Honeybadger.configure do |config|
    #     config.api_key = '1234567890abcdef'
    #     config.secure  = false
    #   end
    #
    # Yields Honeybadger configuration
    def configure(silent = false)
      yield(configuration)
      self.sender = Sender.new(configuration)
      report_ready unless silent
      self.sender
    end

    # Public: The configuration object.
    # See Honeybadger.configure
    #
    # Returns Honeybadger configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Internal: Contacts the Honeybadger service and configures features
    #
    # configuration - the Configuration object to use
    #
    # Returns Hash features on success, NilClass on failure
    def ping(configuration)
      if configuration.public?
        if result = sender.ping({ :version => Honeybadger::VERSION, :framework => configuration.framework, :environment => configuration.environment_name, :hostname => configuration.hostname })
          if features = result['features']
            configuration.features = features
            configuration.metrics = false unless features['metrics']
            configuration.traces = false unless features['traces']
            features
          end
        end
      end
    end

    # Public: Sends an exception manually using this method, even when you are not in a controller.
    #
    # exception - The exception you want to notify Honeybadger about.
    # options   - Data that will be sent to Honeybadger.
    #             :api_key          - The API key for this project. The API key is a unique identifier
    #                                 that Honeybadger uses for identification.
    #             :error_message    - The error returned by the exception (or the message you want to log).
    #             :backtrace        - A backtrace, usually obtained with +caller+.
    #             :rack_env         - The Rack environment.
    #             :session          - The contents of the user's session.
    #             :environment_name - The application environment name.
    #             :context          - Custom hash to send
    #
    # Returns exception ID from Honeybadger on success, false on failure
    def notify(exception, options = {})
      send_notice(build_notice_for(exception, options))
    end

    # Public: Sends the notice unless it is one of the default ignored exceptions
    # see Honeybadger.notify
    def notify_or_ignore(exception, opts = {})
      notice = build_notice_for(exception, opts)
      send_notice(notice) unless notice.ignore?
    end

    def build_lookup_hash_for(exception, options = {})
      notice = build_notice_for(exception, options)

      result = {}
      result[:action]           = notice.action      rescue nil
      result[:component]        = notice.component   rescue nil
      result[:error_class]      = notice.error_class if notice.error_class
      result[:environment_name] = 'production'

      unless notice.backtrace.lines.empty?
        result[:file]        = notice.backtrace.lines[0].file
        result[:line_number] = notice.backtrace.lines[0].number
      end

      result
    end

    def context(hash = nil)
      unless hash.nil?
        Thread.current[:honeybadger_context] ||= {}
        Thread.current[:honeybadger_context].merge!(hash)
      end

      self
    end

    def clear!
      Thread.current[:honeybadger_context] = nil
    end

    private

    def send_notice(notice)
      return false unless sender

      if configuration.public?
        if configuration.async?
          configuration.async.call(notice)
        else
          Honeybadger.sender.send_to_honeybadger(notice)
        end
      end
    end

    def build_notice_for(exception, opts = {})
      exception = unwrap_exception(exception)
      opts = opts.merge(:exception => exception) if exception.is_a?(Exception)
      opts = opts.merge(exception.to_hash) if exception.respond_to?(:to_hash)
      Notice.new(configuration.merge(opts))
    end

    def unwrap_exception(exception)
      return exception unless configuration.unwrap_exceptions
      exception.respond_to?(:original_exception) && exception.original_exception ||
      exception.respond_to?(:continued_exception) && exception.continued_exception ||
      exception.respond_to?(:cause) && exception.cause ||
      exception
    end
  end
end

unless defined?(Rails)
  Honeybadger::Dependency.inject!
end
