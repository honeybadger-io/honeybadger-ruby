require 'forwardable'
require 'net/http'

require 'honeybadger/logging'

module Honeybadger
  # Internal: A concurrent queue to notify the backend.
  class Worker
    extend Forwardable

    include Honeybadger::Logging::Helper

    # Internal: Sub-class thread so we have a named thread (useful for debugging in Thread.list).
    class Thread < ::Thread; end

    # Internal: A queue which enforces a maximum size.
    class Queue < ::Queue
      attr_reader :max_size

      def initialize(max_size)
        @max_size = max_size
        super()
      end

      def push(msg)
        super unless size == max_size
      end
    end

    SHUTDOWN = :__hb_worker_shutdown!

    def initialize(config)
      @config = config
      @throttles = []
      @mutex = Mutex.new
      @marker = ConditionVariable.new
      @queue = Queue.new(config.max_queue_size)
      @shutdown = false
      @start_at = nil
    end

    def push(msg)
      return false unless start
      queue.push(msg)
    end

    def send_now(msg)
      handle_response(msg, notify_backend(msg))
    end

    # Internal: Shutdown the worker after sending remaining data.
    #
    # Returns true.
    def shutdown
      d { 'shutting down worker' }

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

      d { 'killing worker thread' }

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

    attr_reader :config, :queue, :pid, :mutex, :marker,
      :thread, :throttles

    def_delegator :config, :backend

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
        d { 'worker started' }
        loop do
          case msg = queue.pop
          when SHUTDOWN then break
          when ConditionVariable then signal_marker(msg)
          else work(msg)
          end
        end
      ensure
        d { 'stopping worker' }
      end
    rescue Exception => e
      error {
        msg = "error in worker thread (shutting down) class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    ensure
      release_marker
    end

    def work(msg)
      send_now(msg)
      sleep(throttle_interval)
    rescue StandardError => e
      error {
        msg = "Error in worker thread class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
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
      debug { sprintf('worker notifying backend id=%s', payload.id) }
      backend.notify(:notices, payload)
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

    def handle_response(msg, response)
      debug { sprintf('worker response code=%s message=%s', response.code, response.message.to_s.dump) }

      case response.code
      when 429, 503
        warn { sprintf('Error report failed: project is sending too many errors. id=%s code=%s throttle=1.25 interval=%s', msg.id, throttle_interval, response.code) }
        add_throttle(1.25)
      when 402
        warn { sprintf('Error report failed: payment is required. id=%s code=%s', msg.id, response.code) }
        suspend(3600)
      when 403
        warn { sprintf('Error report failed: API key is invalid. id=%s code=%s', msg.id, response.code) }
        suspend(3600)
      when 201
        if throttle = del_throttle
          info { sprintf('Success ⚡ https://app.honeybadger.io/notice/%s id=%s code=%s throttle=%s interval=%s', msg.id, msg.id, response.code, throttle_interval, response.code) }
        else
          info { sprintf('Success ⚡ https://app.honeybadger.io/notice/%s id=%s code=%s', msg.id, msg.id, response.code) }
        end
      when :error
        warn { sprintf('Error report failed: an unknown error occurred. code=%s error=%s', response.code, response.message.to_s.dump) }
      else
        warn { sprintf('Error report failed: unknown response from server. code=%s', response.code) }
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
