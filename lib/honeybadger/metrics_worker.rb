require 'honeybadger/logging'

module Honeybadger
  # A concurrent queue to execute plugin collect blocks and registry.
  # @api private
  class MetricsWorker
    extend Forwardable

    include Honeybadger::Logging::Helper

    # Sub-class thread so we have a named thread (useful for debugging in Thread.list).
    class Thread < ::Thread; end

    # Used to signal the worker to shutdown.
    SHUTDOWN = :__hb_worker_shutdown!

    def initialize(config)
      @config = config
      @interval_seconds = 1
      @mutex = Mutex.new
      @marker = ConditionVariable.new
      @queue = Queue.new
      @shutdown = false
      @start_at = nil
      @pid = Process.pid
    end

    def push(msg)
      return false unless config.insights_enabled?
      return false unless start

      queue.push(msg)
    end

    def send_now(msg)
      return if msg.tick > 0

      msg.call
      msg.reset
    end

    def shutdown(force = false)
      d { 'shutting down worker' }

      mutex.synchronize do
        @shutdown = true
      end

      return true if force
      return true unless thread&.alive?

      queue.push(SHUTDOWN)
      !!thread.join
    ensure
      queue.clear
      kill!
    end

    # Blocks until queue is processed up to this point in time.
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

        return true if thread&.alive?

        @pid = Process.pid
        @thread = Thread.new { run }
      end

      true
    end

    private

    attr_reader :config, :queue, :pid, :mutex, :marker, :thread, :interval_seconds, :start_at

    def shutdown?
      mutex.synchronize { @shutdown }
    end

    def suspended?
      mutex.synchronize { start_at && Time.now.to_i < start_at }
    end

    def can_start?
      return false if shutdown?
      return false if suspended?
      true
    end

    def kill!
      d { 'killing worker thread' }

      if thread
        Thread.kill(thread)
        thread.join # Allow ensure blocks to execute.
      end

      true
    end

    def suspend(interval)
      mutex.synchronize do
        @start_at = Time.now.to_i + interval
        queue.clear
      end

      # Must be performed last since this may kill the current thread.
      kill!
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
        msg = "Error in worker thread (shutting down) class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    ensure
      release_marker
    end

    def work(msg)
      send_now(msg)

      if shutdown?
        kill!
        return
      end
    rescue StandardError => e
      error {
        err = "Error in worker thread class=%s message=%s\n\t%s"
        sprintf(err, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    ensure
      queue.push(msg) unless shutdown? || suspended?
      sleep(interval_seconds)
    end

    # Release the marker. Important to perform during cleanup when shutting
    # down, otherwise it could end up waiting indefinitely.
    def release_marker
      signal_marker(marker)
    end

    def signal_marker(marker)
      mutex.synchronize do
        marker.signal
      end
    end
  end
end
