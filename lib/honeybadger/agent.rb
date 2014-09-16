require 'forwardable'

require 'honeybadger/version'
require 'honeybadger/config'
require 'honeybadger/worker'
require 'honeybadger/notice'
require 'honeybadger/plugin'
require 'honeybadger/logging'

module Honeybadger
  # Internal: A broker for the configuration and the worker.
  class Agent
    extend Forwardable

    include Logging::Helper

    class << self
      extend Forwardable

      def_delegators :callbacks, :exception_filter, :exception_fingerprint, :backtrace_filter

      def callbacks
        @callbacks ||= Config::Callbacks.new
      end
    end

    private

    def self.load_plugins(config)
      Dir[File.expand_path('../plugins/*.rb', __FILE__)].each do |plugin|
        require plugin
      end
      Plugin.load!(config)
    end

    public

    def self.instance
      @instance
    end

    def self.running?
      !instance.nil?
    end

    def self.start(config = {})
      return true if running?

      unless config.kind_of?(Config)
        config = Config.new(config)
      end

      if config[:disabled]
        config.logger.info('Unable to start Honeybadger -- disabled by configuration.')
        return false
      elsif !config.valid?
        config.logger.warn('Unable to start Honeybadger -- invalid configuration.')
        return false
      elsif !config.ping
        config.logger.warn('Unable to start Honeybadger -- failed to connect to server.')
        return false
      end

      config.logger.info("Starting Honeybadger version #{VERSION}")
      load_plugins(config)
      @instance = new(config)
      @instance.start
    end

    def self.stop(*args)
      @instance.stop(*args) if @instance
      @instance = nil
    end

    def self.fork(*args)
      self.instance ? self.instance.fork(*args) : false
    end

    def self.trace(*args)
      self.instance ? self.instance.trace(*args) : false
    end

    def self.timing(*args)
      self.instance ? self.instance.timing(*args) : false
    end

    def self.increment(*args)
      self.instance ? self.instance.increment(*args) : false
    end

    # Internal: Callback to perform after agent has been stopped at_exit.
    #
    # block - An optional block to execute.
    #
    # Returns Proc callback.
    def self.at_exit(&block)
      @at_exit = Proc.new if block_given?
      @at_exit
    end

    # Internal: Not for public consumption. :)
    #
    # Prefer dependency injection over accessing config directly, but some
    # cases (such as the delayed_job plugin) necessitate it.
    #
    # Returns the Agent's config if running, otherwise default config
    def self.config
      if running?
        instance.send(:config)
      else
        @config ||= Config.new
      end
    end

    def initialize(config)
      @config = config
      @worker = Worker.new(config)

      at_exit do
        stop
        self.class.at_exit.call if self.class.at_exit
      end
    end

    def_delegators :@worker, :start, :fork, :trace, :timing, :increment

    def stop(force = false)
      info("Shutting down Honeybadger version #{VERSION}")
      worker.stop(force)
    end

    def notice(opts)
      opts.merge!(callbacks: self.class.callbacks)
      notice = Notice.new(config, opts)

      if notice.ignore?
        debug { sprintf('ignore notice feature=notices id=%s', notice.id) }
        false
      else
        debug { sprintf('notice feature=notices id=%s', notice.id) }
        worker.notice(notice)
        notice.id
      end
    end

    private

    attr_reader :worker, :config
  end
end
