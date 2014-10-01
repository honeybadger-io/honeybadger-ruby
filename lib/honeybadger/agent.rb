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

    # Internal: Sub-class thread so we have a named thread (useful for debugging in Thread.list).
    class Thread < ::Thread; end

    autoload :Worker, 'honeybadger/agent/worker'
    autoload :NullWorker, 'honeybadger/agent/worker'
    autoload :Batch, 'honeybadger/agent/batch'
    autoload :MetricsCollector, 'honeybadger/agent/metrics_collector'

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
        config.logger.warn('Unable to start Honeybadger -- disabled by configuration.')
        return false
      elsif !config.valid?
        config.logger.warn('Unable to start Honeybadger -- api_key is missing or invalid.')
        return false
      elsif !config.ping
        config.logger.warn('Unable to start Honeybadger -- failed to connect to server.')
        return false
      end

      config.logger.info("Starting Honeybadger version #{VERSION}")
      load_plugins(config)
      @instance = new(config)

      true
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
      @delay = config[:debug] ? 10 : 60
      @mutex = Mutex.new
      @pid = Process.pid

      unless config.backend.kind_of?(Backend::Server)
        warn('Initializing development backend: data will not be reported.')
      end

      init_workers
      init_traces
      init_metrics

      at_exit do
        stop
        self.class.at_exit.call if self.class.at_exit
      end
    end

    # Internal: Spawn the agent thread. This method is idempotent.
    #
    # Returns false if the Agent is stopped, otherwise true.
    def start
      return false unless pid
      return true if thread && thread.alive?

      @pid = Process.pid
      @thread = Thread.new { run }

      true
    end

    def stop(force = false)
      debug { 'stopping agent' }

      # Kill the collector
      Thread.kill(thread) if thread

      unless force
        flush_traces
        flush_metrics
      end

      workers.each_pair do |key, worker|
        worker.send(force ? :shutdown! : :shutdown)
      end

      @pid = @thread = nil

      true
    end

    def fork
      # noop
    end

    def notice(opts)
      opts.merge!(callbacks: self.class.callbacks)
      notice = Notice.new(config, opts)

      if notice.ignore?
        debug { sprintf('ignore notice feature=notices id=%s', notice.id) }
        false
      else
        debug { sprintf('notice feature=notices id=%s', notice.id) }
        workers[:notices].push(notice)
        notice.id
      end
    end

    def trace(trace)
      start

      if trace.duration > config[:'traces.threshold']
        debug { sprintf('agent adding trace duration=%s feature=traces id=%s', trace.duration.round(2), trace.id) }
        mutex.synchronize { traces.push(trace) }
        flush_traces if traces.flush?
        true
      else
        debug { sprintf('agent discarding trace duration=%s feature=traces id=%s', trace.duration.round(2), trace.id) }
        false
      end
    end

    def timing(*args, &block)
      start

      mutex.synchronize { metrics.timing(*args, &block) }
      flush_metrics if metrics.flush?

      true
    end

    def increment(*args, &block)
      start

      mutex.synchronize { metrics.increment(*args, &block) }
      flush_metrics if metrics.flush?

      true
    end

    private

    attr_reader :config, :delay, :mutex, :workers, :pid, :thread, :traces, :metrics

    def push(feature, object)
      unless config.features[feature]
        debug { sprintf('agent dropping feature=%s reason=ping', feature) }
        return false
      end

      workers[feature].push(object)

      true
    end

    def run
      loop { work }
    rescue Exception => e
      error(sprintf('error in agent thread (shutting down) class=%s message=%s at=%s', e.class, e.message.dump, e.backtrace.first.dump))
    ensure
      d { sprintf('stopping agent', feature) }
    end

    def work
      flush_metrics if metrics.flush?
      flush_traces if traces.flush?
    rescue StandardError => e
      error(sprintf('error in agent thread class=%s message=%s at=%s', e.class, e.message.dump, e.backtrace.first.dump))
    ensure
      sleep(delay)
    end

    def init_workers
      @workers = Hash.new(NullWorker.new)
      workers[:notices] = Worker.new(config, :notices)
      workers[:traces]  = Worker.new(config, :traces)
      workers[:metrics] = Worker.new(config, :metrics)
    end

    def init_traces
      @traces = Batch.new(config, :traces, 20, config[:debug] ? 10 : 60)
    end

    def init_metrics
      @metrics = MetricsCollector.new(config, config[:debug] ? 10 : 60)
    end

    def flush_metrics
      debug { 'agent flushing metrics feature=metrics' } # TODO: Include count.
      mutex.synchronize do
        metrics.chunk(100, &method(:push).to_proc.curry[:metrics])
        init_metrics
      end
    end

    def flush_traces
      debug { sprintf('agent flushing traces feature=traces count=%d', traces.size) }
      mutex.synchronize do
        push(:traces, traces) unless traces.empty?
        init_traces
      end
    end
  end
end
