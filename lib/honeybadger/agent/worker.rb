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
        @queue = Queue.new(1000)
        @shutdown = false
      end

      def push(obj)
        if start
          queue.push(obj)
        end
      end

      # Internal: Shutdown the worker.
      #
      # timeout - The Integer timeout to wait before killing thread.
      #
      # Returns false if timeout reached, otherwise true.
      def shutdown(timeout = 3)
        mutex.synchronize do
          @shutdown = true
          @pid = nil
          queue.push(SHUTDOWN)
        end

        return true unless thread

        r = true
        unless Thread.current.eql?(thread)
          begin
            r = !!thread.join(timeout)
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
        mutex.synchronize do
          return false if @shutdown
          return true if thread && thread.alive?

          @pid = Process.pid
          @thread = Thread.new { run }
        end

        true
      end

      private

      attr_reader :config, :backend, :feature, :queue, :pid, :mutex, :marker,
        :thread, :throttles

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
        error(sprintf('error in worker thread (shutting down) feature=%s class=%s message=%s at=%s', feature, e.class, e.message.dump, e.backtrace.first.dump))
      ensure
        release_marker
      end

      def process(msg)
        handle_response(notify_backend(msg))
        sleep(throttle_interval)
      rescue StandardError => e
        error(sprintf('error in worker thread feature=%s class=%s message=%s at=%s', feature, e.class, e.message.dump, e.backtrace.first.dump))
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
          warn { sprintf('worker shutting down (payment required) feature=%s code=%s', feature, response.code) }
          shutdown!
        when 403
          warn { sprintf('worker shutting down (unauthorized) feature=%s code=%s', feature, response.code) }
          shutdown!
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
