require 'forwardable'

require 'honeybadger/version'
require 'honeybadger/config'
require 'honeybadger/notice'
require 'honeybadger/plugin'
require 'honeybadger/logging'

module Honeybadger
  # Internal: A broker for the configuration and the workers.
  class Agent
    extend Forwardable

    include Logging::Helper

    autoload :Worker, 'honeybadger/agent/worker'
    autoload :NullWorker, 'honeybadger/agent/worker'

    class << self
      extend Forwardable

      def_delegators :callbacks, :exception_filter, :exception_fingerprint, :backtrace_filter

      def callbacks
        @callbacks ||= Config::Callbacks.new
      end
    end

    private

    def self.load_plugins!(config)
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
        config.logger.warn('Unable to start Honeybadger -- disabled by configuration.')
        return false
      elsif !config.valid?
        config.logger.warn('Unable to start Honeybadger -- api_key is missing or invalid.')
        return false
      end

      unless config.ping
        config.logger.warn('Failed to connect to Honeybadger service -- please verify that api.honeybadger.io is reachable (connection will be retried).')
      end

      config.logger.info("Starting Honeybadger version #{VERSION}")
      load_plugins!(config)
      @instance = new(config)

      true
    end

    def self.stop(*args)
      @instance.stop(*args) if @instance
      @instance = nil
    end

    def self.fork(*args)
      # noop
    end

    def self.flush(&block)
      if self.instance
        self.instance.flush(&block)
      elsif !block_given?
        false
      else
        yield
      end
    end

    def self.notify(exception_or_opts, opts = {})
      self.instance ? self.instance.notify(exception_or_opts, opts) : false
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

    attr_reader :workers

    def initialize(config)
      @config = config
      @mutex = Mutex.new

      unless config.backend.kind_of?(Backend::Server)
        warn('Initializing development backend: data will not be reported.')
      end

      init_workers

      at_exit do
        # Fix for https://bugs.ruby-lang.org/issues/5218
        if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby' && RUBY_VERSION =~ /1\.9/
          exit_status = $!.status if $!.is_a?(SystemExit)
        end

        notify_at_exit($!)
        stop if config[:'send_data_at_exit']
        self.class.at_exit.call if self.class.at_exit

        exit(exit_status) if exit_status
      end
    end

    def stop(force = false)
      workers.each_pair do |key, worker|
        worker.send(force ? :shutdown! : :shutdown)
      end

      true
    end

    def notify(exception_or_opts, opts)
      opts.merge!(exception: exception_or_opts) if exception_or_opts.is_a?(Exception)
      opts.merge!(exception_or_opts.to_hash) if exception_or_opts.respond_to?(:to_hash)

      opts.merge!(callbacks: self.class.callbacks)
      notice = Notice.new(config, opts)

      if !opts[:force] && notice.ignore?
        debug { sprintf('ignore notice feature=notices id=%s', notice.id) }
        false
      else
        debug { sprintf('notice feature=notices id=%s', notice.id) }
        push(:notices, notice)
        notice.id
      end
    end

    # Internal: Flush the workers. See Honeybadger#flush.
    #
    # block - an option block which is executed before flushing data.
    #
    # Returns value from block if block is given, otherwise true.
    def flush
      return true unless block_given?
      yield
    ensure
      workers.values.each(&:flush)
    end

    private

    attr_reader :config, :mutex

    def push(feature, object)
      unless config.feature?(feature)
        debug { sprintf('agent dropping feature=%s reason=ping', feature) }
        return false
      end

      workers[feature].push(object)

      true
    end

    def init_workers
      @workers = Hash.new(NullWorker.new)
      workers[:notices] = Worker.new(config, :notices)
    end

    def notify_at_exit(ex)
      return unless ex
      return unless config[:'exceptions.notify_at_exit']
      return if ex.is_a?(SystemExit)

      notify(ex, component: 'at_exit')
    end
  end
end
