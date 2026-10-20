require "forwardable"
require "net/http"

require "honeybadger/logging"

module Honeybadger
  # A concurrent queue to notify the backend.
  # @api private
  class Worker
    extend Forwardable

    include Honeybadger::Logging::Helper

    # Sub-class thread so we have a named thread (useful for debugging in Thread.list).
    class Thread < ::Thread; end

    # Used to signal the worker to shutdown.
    SHUTDOWN = :__hb_worker_shutdown!

    # Number of times a notice is resent while the server is unavailable
    # (6 attempts in total). Each notice gets its own retries.
    MAX_RETRIES = 5

    def initialize(config)
      @config = config
      @mutex = Mutex.new
      @flush_signal = ConditionVariable.new
      @queue = Queue.new
      @shutdown = false
      @flushes = 0
      @start_at = nil
      @pid = Process.pid
    end

    def push(msg)
      return false unless start

      if queue.size >= config.max_queue_size
        warn { sprintf("Unable to report error; reached max queue size of %s. id=%s", queue.size, msg.id) }
        return false
      end

      queue.push(msg)
    end

    # Sends synchronously without retrying.
    def send_now(msg)
      response = notify_backend(msg)
      run_after_notify_hooks(msg, response)
      handle_response(msg, response)
    end

    def shutdown(force = false)
      d { "shutting down worker" }

      mutex.synchronize do
        @shutdown = true
      end

      return true if force
      return true unless thread&.alive?

      info { sprintf("Waiting to report %s error(s) to Honeybadger", queue.size) } unless queue.empty?

      queue.push(SHUTDOWN)
      !!thread.join
    ensure
      queue.clear
      kill!
    end

    # Blocks until queue is processed up to this point in time. Retries are
    # skipped while a flush is pending, since the caller is waiting.
    def flush
      mutex.synchronize do
        if thread&.alive?
          @flushes += 1
          queue.push(flush_signal)
          begin
            flush_signal.wait(mutex)
          ensure
            @flushes -= 1
          end
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

    attr_reader :config, :queue, :pid, :mutex, :flush_signal, :thread, :start_at

    def_delegator :config, :backend

    def shutdown?
      mutex.synchronize { @shutdown }
    end

    def flushing?
      mutex.synchronize { @flushes > 0 }
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
      d { "killing worker thread" }

      if thread
        Thread.kill(thread)
        thread.join # Allow ensure blocks to execute.
      end

      true
    end

    # Drops queued notices and rejects new ones (push returns false) for
    # +interval+ seconds. The thread restarts on the first push after that.
    def suspend(interval)
      warn { sprintf("Dropping queued errors and rejecting new ones for %ss", interval) }
      mutex.synchronize do
        @start_at = Time.now.to_i + interval
        queue.clear
      end

      # Must be performed last since this may kill the current thread.
      kill!
    end

    def run
      begin
        d { "worker started" }
        loop do
          case msg = queue.pop
          when SHUTDOWN then break
          when flush_signal then signal_flush_done
          else work(msg)
          end
        end
      ensure
        d { "stopping worker" }
      end
    rescue => e
      error {
        msg = "Error in worker thread (shutting down) class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    ensure
      release_flush_waiters
    end

    def work(msg)
      response = notify_backend(msg)
      MAX_RETRIES.times do
        break unless response.retryable?
        break unless wait(response.retry_after || rand(5..15))
        response = notify_backend(msg)
      end
      run_after_notify_hooks(msg, response)
      handle_response(msg, response)
      if (interval = response.reject_interval)
        suspend(interval) # terminates this thread
      end

      # Shutting down while the server is unavailable: stop without sending
      # the rest of the queue.
      if shutdown? && response.retryable?
        warn { "Shutting down while the server is unavailable; dropping queued errors" }
        kill!
      end
    rescue => e
      error {
        msg = "Error in worker thread class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    end

    def notify_backend(payload)
      d { sprintf("worker notifying backend id=%s", payload.id) }
      backend.notify(:notices, payload)
    end

    def run_after_notify_hooks(msg, response)
      config.after_notify_hooks.each do |hook|
        with_error_handling { hook.call(msg, response) }
      end
    end

    def with_error_handling
      yield
    rescue => ex
      error {
        msg = "Rescued an error in an after notify hook class=%s message=%s\n\t%s"
        sprintf(msg, ex.class, ex.message.dump, Array(ex.backtrace).join("\n\t"))
      }
    end

    # Sleeps in one-second steps so shutdown or a flush can interrupt.
    # Returns false if one did, including during the final second; the
    # payload in hand is then dropped.
    def wait(seconds)
      seconds.times do
        return false if shutdown? || flushing?
        sleep(1)
      end
      !(shutdown? || flushing?)
    end

    def handle_response(msg, response)
      d { sprintf("worker response id=%s code=%s message=%s", msg.id, response.code, response.message.to_s.dump) }

      case response.code
      when 429, 502, 503, 504
        if response.retryable?
          warn { sprintf("Error report failed: server unavailable, giving up on this error. id=%s code=%s", msg.id, response.code) }
        else
          warn { sprintf("Error report failed: server is rejecting data. id=%s code=%s reason=%s", msg.id, response.code, response.limit_reason) }
        end
      when 401, 403
        warn { sprintf("Error report failed: %s id=%s code=%s", response.error_message, msg.id, response.code) }
      when 413
        warn { sprintf("Error report failed: Payload is too large. id=%s code=%s", msg.id, response.code) }
      when 201
        host = config.get(:"connection.ui_host")
        info { sprintf("Success ⚡ https://%s/notice/%s id=%s code=%s", host, msg.id, msg.id, response.code) }
      when :stubbed
        debug { sprintf("Success ⚡ Development mode is enabled; this error will be reported if it occurs after you deploy your app. id=%s", msg.id) }
      when :error
        warn { sprintf("Error report failed: an unknown error occurred. code=%s error=%s", response.code, response.message.to_s.dump) }
      else
        warn { sprintf("Error report failed: unknown response from server. code=%s", response.code) }
      end
    end

    # Wake every waiting flush. Important to perform during cleanup when
    # shutting down, otherwise they could end up waiting indefinitely.
    def release_flush_waiters
      if mutex.owned?
        flush_signal.broadcast
      else
        mutex.synchronize { flush_signal.broadcast }
      end
    end

    # Wakes the flush waiting on this point in the queue.
    def signal_flush_done
      if mutex.owned?
        flush_signal.signal
      else
        mutex.synchronize { flush_signal.signal }
      end
    end
  end
end
