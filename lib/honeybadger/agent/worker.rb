require 'forwardable'
require 'net/http'

require 'honeybadger/logging'
require 'honeybadger/agent/null_worker'

module Honeybadger
  class Agent
    # Internal: A concurrent queue to notify the backend.
    class Worker
      extend Forwardable

      include Honeybadger::Logging::Helper

      # Internal: See Agent::Thread
      class Thread < ::Thread; end

      # Internal: A queue which enforces a maximum size.
      class Queue < ::Queue
        attr_reader :max_size

        def initialize(max_size)
          @max_size = max_size
          super()
        end

        def push(obj)
          super unless size == max_size
        end
      end

      SHUTDOWN = :__hb_worker_shutdown!

      def initialize(config, feature)
        @config = config
        @feature = feature
        @backend = config.backend
        @throttles = []
        @mutex = Mutex.new
        @marker = ConditionVariable.new
        @queue = Queue.new(config.max_queue_size)
        @shutdown = false
        @start_at = nil
      end

      def push(obj)
        return false unless start
        queue.push(obj)
      end

      # Internal: Shutdown the worker after sending remaining data.
      #
      # Returns true.
      def shutdown
        mutex.synchronize do
          @shutdown = true
          @pid = nil
          queue.push(SHUTDOWN)
        end

        return true unless thread

        r = true
        unless Thread.current.eql?(thread)
          begin
            r = !!thread.join
          ensure
            shutdown! unless r
          end
        end

        r
      end

      def shutdown!
        mutex.synchronize do
          @shutdown = true
          @pid = nil
          queue.clear
        end

        d { sprintf('killing worker thread feature=%s', feature) }

        if thread
          Thread.kill(thread)
          thread.join # Allow ensure blocks to execute.
        end

        true
      end

      # Internal: Blocks until queue is processed up to this point in time.
      #
      # Returns nothing.
      def flush
        mutex.synchronize do
          if thread && thread.alive?
            queue.push(marker)
            marker.wait(mutex)
          end
        end
      end

      def start
        return false unless can_start?

        mutex.synchronize do
          @shutdown = false
          @start_at = nil

          return true if thread && thread.alive?

          @pid = Process.pid
          @thread = Thread.new { run }
        end

        true
      end

      private

      attr_reader :config, :backend, :feature, :queue, :pid, :mutex, :marker,
        :thread, :throttles

      def can_start?
        mutex.synchronize do
          return true unless @shutdown
          return false unless @start_at
          Time.now.to_i >= @start_at
        end
      end

      def suspend(interval)
        mutex.synchronize { @start_at = Time.now.to_i + interval }

        # Must be performed last since this may kill the current thread.
        shutdown!
      end

      def run
        begin
          d { sprintf('worker started feature=%s', feature) }
          loop do
            case msg = queue.pop
            when SHUTDOWN then break
            when ConditionVariable then signal_marker(msg)
            else process(msg)
            end
          end
        ensure
          d { sprintf('stopping worker feature=%s', feature) }
        end
      rescue Exception => e
        error {
          msg = "error in worker thread (shutting down) feature=%s class=%s message=%s\n\t%s"
          sprintf(msg, feature, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
        }
      ensure
        release_marker
      end

      def process(msg)
        handle_response(notify_backend(msg))
        sleep(throttle_interval)
      rescue StandardError => e
        error {
          msg = "error in worker thread feature=%s class=%s message=%s\n\t%s"
          sprintf(msg, feature, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
        }
        sleep(1)
      end

      def throttle_interval
        return 0 unless throttles[0]
        mutex.synchronize do
          throttles.reduce(1) {|a,e| a*e }
        end
      end

      def notify_backend(payload)
        debug { sprintf('worker notifying backend feature=%s id=%s', feature, payload.id) }
        backend.notify(feature, payload)
      end

      def add_throttle(t)
        mutex.synchronize do
          throttles.push(t)
        end
      end

      def del_throttle
        mutex.synchronize do
          throttles.shift
        end
      end

      def handle_response(response)
        debug { sprintf('worker response feature=%s code=%s message=%s', feature, response.code, response.message.to_s.dump) }

        case response.code
        when 429, 503
          add_throttle(1.25)
          debug { sprintf('worker applying throttle=1.25 interval=%s feature=%s code=%s', throttle_interval, feature, response.code) }
        when 402
          warn { sprintf('data will not be reported (payment required) feature=%s code=%s', feature, response.code) }
          suspend(3600)
        when 403
          warn { sprintf('data will not be reported feature=%s code=%s error=%s', feature, response.code, response.error.to_s.dump) }
          suspend(3600)
        when 201
          if throttle = del_throttle
            debug { sprintf('worker removing throttle=%s interval=%s feature=%s code=%s', throttle, throttle_interval, feature, response.code) }
          end
        when :error
          # Error logged by backend.
        else
          warn { sprintf('worker unknown response feature=%s code=%s', feature, response.code) }
        end
      end

      # Internal: Release the marker. Important to perform during cleanup when
      # shutting down, otherwise it could end up waiting indefinitely.
      #
      # Returns nothing.
      def release_marker
        signal_marker(marker)
      end

      # Internal: Signal a marker.
      #
      # marker - The ConditionVariable marker to signal.
      #
      # Returns nothing.
      def signal_marker(marker)
        mutex.synchronize do
          marker.signal
        end
      end
    end
  end
end
