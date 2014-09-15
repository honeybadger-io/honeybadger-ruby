require 'forwardable'
require 'net/http'

require 'honeybadger/logging'

module Honeybadger
  class Worker
    extend Forwardable

    include Honeybadger::Logging::Helper

    autoload :Batch, 'honeybadger/worker/batch'
    autoload :MetricsCollector, 'honeybadger/worker/metrics_collector'
    autoload :MeteredQueue, 'honeybadger/worker/metered_queue'

    # Sub-class thread so we have a named thread (useful for debugging in Thread.list).
    class Thread < ::Thread; end

    attr_reader :backend, :queue, :features, :metrics, :traces, :pid, :mutex, :thread

    def initialize(config)
      @backend = config.backend
      @config = config
      @mutex = Mutex.new
      prepare
    end

    def start
      debug { 'starting worker' }

      @pid = Process.pid
      @thread = Thread.new { run }

      true
    end

    def stop(force = false)
      debug { 'stopping worker' }
      if thread
        if force
          debug { 'killing worker' }
          Thread.kill(thread)
        else
          thread[:should_exit] = true
          unless thread.eql?(Thread.current)
            mutex.unlock if mutex.locked?
            thread.join
          end
        end
      end
      @thread = nil
      @pid = nil
    end

    def fork
      debug { 'forking worker' }

      stop

      mutex.synchronize { prepare }

      start
    end

    def notice(notice)
      debug { sprintf('worker adding notice feature=notices id=%s', notice.id) }
      push(:notices, notice)
    end

    def trace(trace)
      if trace.duration > config[:'traces.threshold']
        debug { sprintf('worker adding trace duration=%s feature=traces id=%s', trace.duration.round(2), trace.id) }
        traces.push(trace)
        flush_traces if traces.flush?
        true
      else
        debug { sprintf('worker discarding trace duration=%s feature=traces id=%s', trace.duration.round(2), trace.id) }
        false
      end
    end

    def timing(*args, &block)
      metrics.timing(*args, &block)
      flush_metrics if metrics.flush?
      true
    end

    def increment(*args, &block)
      metrics.increment(*args, &block)
      flush_metrics if metrics.flush?
      true
    end

    private

    attr_reader :config

    def init_queue
      @queue = {
        notices: MeteredQueue.new,
        metrics: MeteredQueue.new,
        traces: MeteredQueue.new
      }.freeze

      @features = {
        notices: true,
        metrics: true,
        traces: true
      }.freeze
    end

    def init_traces
      @traces = Batch.new(config, :traces, 20, config[:debug] ? 10 : 60)
    end

    def init_metrics
      @metrics = MetricsCollector.new(config, config[:debug] ? 10 : 60)
    end

    def flush_metrics
      debug { 'worker flushing metrics feature=metrics' } # TODO: Include count.
      mutex.synchronize do
        metrics.chunk(100, &method(:push).to_proc.curry[:metrics])
        init_metrics
      end
    end

    def flush_traces
      debug { sprintf('worker flushing traces feature=traces count=%d', traces.size) }
      mutex.synchronize do
        push(:traces, traces) unless traces.empty?
        init_traces
      end
    end

    def flush_queue
      mutex.synchronize do
        queue.each_pair do |feature, queue|
          while payload = queue.pop!
            handle_response(feature, notify_backend(feature, payload))
          end
        end
      end
    end

    def prepare
      init_queue
      init_metrics
      init_traces
    end

    def push(feature, object)
      unless features[feature]
        debug { sprintf('worker dropping feature=%s reason=collector', feature) }
        return false
      end

      unless config.features[feature]
        debug { sprintf('worker dropping feature=%s reason=ping', feature) }
        return false
      end

      queue[feature].push(object)

      true
    end

    def run
      begin
        debug { 'worker started' }
        work until finish
      rescue Exception => e
        error(sprintf('error in worker thread (shutting down) class=%s message=%s location=%s', e.class, e.message.dump, e.backtrace.first.dump))
        raise e
      ensure
        debug { 'stopping worker' }
      end
    end

    def work
      flush_metrics if metrics.flush?
      flush_traces if traces.flush?

      queue.each_pair do |feature, queue|
        if payload = queue.pop
          handle_response(feature, notify_backend(feature, payload))
        end
      end

      sleep(0.1)
    rescue StandardError => e
      error(sprintf('error in worker thread class=%s message=%s location=%s', e.class, e.message.dump, e.backtrace.first.dump))
      sleep(1)
    end

    def finish
      if Thread.current[:should_exit]
        debug { 'flushing worker data' }

        flush_metrics
        flush_traces
        flush_queue

        true
      end
    end

    def notify_backend(feature, payload)
      debug { sprintf('worker notifying backend feature=%s id=%s', feature, payload.id) }
      backend.notify(feature, payload)
    end

    def handle_response(feature, response)
      debug { sprintf('worker response feature=%s code=%s message=%s', feature, response.code, response.message.to_s.dump) }

      case response.code
      when 429, 503
        debug { sprintf('worker applying throttle=1.25 feature=%s code=%s', feature, response.code) }
        queue[feature].throttle(1.25)
      when 402
        warn { sprintf('worker disabling feature=%s code=%s', feature, response.code) }
        mutex.synchronize { features[feature] = false }
      when 403
        error { sprintf('worker shutting down (unauthorized) feature=%s code=%s', feature, response.code) }
        Honeybadger::Agent.stop(true)
      when 201
        if throttle = queue[feature].unthrottle
          debug { sprintf('worker removing throttle=%s feature=%s code=%s', throttle, feature, response.code) }
        end
      when :error
        # Error logged by backend.
      else
        warn { sprintf('worker unknown response feature=%s code=%s', feature, response.code) }
      end
    end
  end
end
