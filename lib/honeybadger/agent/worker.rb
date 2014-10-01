require 'forwardable'
require 'net/http'

require 'honeybadger/logging'

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

      attr_reader :backend, :feature, :queue, :pid, :mutex, :thread, :throttles

      def initialize(config, feature)
        @config = config
        @feature = feature
        @backend = config.backend
        @throttles = []
        @mutex = Mutex.new
        @queue = Queue.new(1000)
        @thread = Thread.new { run }
      end

      def_delegator :queue, :push

      # Internal: Shutdown the worker.
      #
      # timeout - The Integer timeout to wait before killing thread.
      #
      # Returns false if timeout reached, otherwise true.
      def shutdown(timeout = 3)
        push(SHUTDOWN)

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
        d { sprintf('killing worker thread feature=%s', feature) }
        Thread.kill(thread) if thread.alive?
        true
      end

      private

      attr_reader :config

      def run
        d { sprintf('worker started feature=%s', feature) }
        loop do
          msg = queue.pop
          break if msg == SHUTDOWN
          process(msg)
        end
      rescue Exception => e
        error(sprintf('error in worker thread (shutting down) feature=%s class=%s message=%s at=%s', feature, e.class, e.message.dump, e.backtrace.first.dump))
      ensure
        d { sprintf('stopping worker feature=%s', feature) }
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
        throttles.reduce(1) {|a,e| a*e }
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
          warn { sprintf('worker disabling feature=%s code=%s', feature, response.code) }
          mutex.synchronize { features[feature] = false } # FIXME
        when 403
          error { sprintf('worker shutting down (unauthorized) feature=%s code=%s', feature, response.code) }
          Honeybadger::Agent.stop(true)
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
    end
  end
end
