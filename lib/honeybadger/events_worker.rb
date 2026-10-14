require "forwardable"
require "net/http"

require "honeybadger/logging"

module Honeybadger
  # A concurrent queue to notify the backend.
  # @api private
  class EventsWorker
    extend Forwardable

    include Honeybadger::Logging::Helper

    # Sub-class thread so we have a named thread (useful for debugging in Thread.list).
    class Thread < ::Thread; end

    # Used to signal the worker to shutdown.
    SHUTDOWN = :__hb_worker_shutdown!
    FLUSH = :__hb_worker_flush!
    CHECK_TIMEOUT = :__hb_worker_check_timeout!

    # Number of times a batch is resent while the server is unavailable
    # (6 attempts in total). Each batch gets its own retries.
    MAX_RETRIES = 5

    # TODO: These could be configurable?

    def initialize(config)
      @config = config
      @mutex = Mutex.new
      @marker = ConditionVariable.new
      @queue = Queue.new
      @shutdown = false
      @flushes = 0
      @start_at = nil
      @pid = Process.pid
      @send_queue = []
      @last_sent = nil
      @dropped_events = 0
    end

    def push(msg)
      return false unless start

      if queue.size >= config.events_max_queue_size
        @dropped_events += 1
        return false
      end

      queue.push(msg)
    end

    def send_now(msg)
      handle_response(send_to_backend(msg))
    end

    def shutdown(force = false)
      d { "shutting down events worker" }

      mutex.synchronize do
        @shutdown = true
      end

      return true if force
      return true unless thread&.alive?

      info { sprintf("Waiting to send %s events(s) to Honeybadger", queue.size) } unless queue.empty?
      queue.push(FLUSH)
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
          queue.push(FLUSH)
          queue.push(marker)
          begin
            marker.wait(mutex)
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
        @timeout_thread = Thread.new { schedule_timeout_check }
      end

      true
    end

    private

    attr_reader :config, :queue, :pid, :mutex, :marker, :thread, :timeout_thread,
      :start_at, :send_queue, :last_sent

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

      if timeout_thread
        Thread.kill(timeout_thread)
        timeout_thread.join # Allow ensure blocks to execute.
      end

      if thread
        Thread.kill(thread)
        thread.join # Allow ensure blocks to execute.
      end

      true
    end

    # Drops queued and pending events and rejects new ones (push returns
    # false) for +interval+ seconds. The thread restarts on the first push after that.
    def suspend(interval)
      mutex.synchronize do
        @start_at = Time.now.to_i + interval
        queue.clear
        send_queue.clear
        @dropped_events = 0
      end

      # Must be performed last since this may kill the current thread.
      kill!
    end

    def schedule_timeout_check
      loop do
        sleep(config.events_timeout / 1000.0)
        queue.push(CHECK_TIMEOUT)
      end
    end

    def run
      begin
        d { "worker started" }
        mutex.synchronize do
          @last_sent = Time.now
        end
        loop do
          case msg = queue.pop
          when SHUTDOWN then break
          when CHECK_TIMEOUT then check_timeout
          when FLUSH then flush_send_queue
          when ConditionVariable then signal_marker(msg)
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
      release_marker
    end

    def check_timeout
      return if mutex.synchronize { send_queue.empty? }
      ms_since = (Time.now.to_f - last_sent.to_f) * 1000.0
      if ms_since >= config.events_timeout
        send_batch
      end
    end

    def enqueue_msg(msg)
      mutex.synchronize do
        @send_queue << msg
      end
    end

    def send_batch
      # batch is send_queue itself; clearing send_queue also clears batch.
      batch = mutex.synchronize { send_queue }
      response = send_to_backend(batch)
      MAX_RETRIES.times do
        break unless response.retryable?
        break unless wait(response.retry_after || rand(5..15))
        response = send_to_backend(batch)
      end
      # A rejection suspends the worker, which clears the batch and
      # terminates this thread.
      handle_response(response)

      mutex.synchronize do
        @last_sent = Time.now
        debug { sprintf("Finished attempting to send %s events", send_queue.length) }
        send_queue.clear
        if @dropped_events > 0
          warn { sprintf("Dropped %s messages due to exceeding max queue size of %s", @dropped_events, config.events_max_queue_size) }
        end
        @dropped_events = 0
      end

      # Shutting down while the server is unavailable: stop without sending
      # the rest of the queue.
      kill! if shutdown? && response.retryable?
    end

    def check_and_send
      return if mutex.synchronize { send_queue.empty? }
      if mutex.synchronize { send_queue.length } >= config.events_batch_size
        send_batch
      end
    end

    def flush_send_queue
      return if mutex.synchronize { send_queue.empty? }
      send_batch
    rescue => e
      error {
        msg = "Error in worker thread class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    end

    def work(msg)
      enqueue_msg(msg)
      check_and_send
    rescue => e
      error {
        msg = "Error in worker thread class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    end

    def send_to_backend(msg)
      d { "events_worker sending to backend" }
      backend.event(msg)
    end

    # Sleeps in one-second steps so shutdown or a flush can interrupt.
    # Returns false if one did, including during the final second; the
    # batch in hand is then dropped.
    def wait(seconds)
      seconds.times do
        return false if shutdown? || flushing?
        sleep(1)
      end
      !(shutdown? || flushing?)
    end

    def handle_response(response)
      d { sprintf("events_worker response code=%s message=%s", response.code, response.message.to_s.dump) }

      case response.code
      when 429, 502, 503, 504
        if response.retryable?
          warn { sprintf("Insights Event send failed: server unavailable, dropping this batch. code=%s", response.code) }
        else
          warn { sprintf("Insights Event send failed: server is rejecting data; dropping queued events and rejecting new ones for %ss. code=%s reason=%s", response.reject_interval, response.code, response.limit_reason) }
          suspend(response.reject_interval)
        end
      when 402
        warn { sprintf("Insights Event send failed: payment is required; dropping queued events and rejecting new ones for %ss. code=%s", response.reject_interval, response.code) }
        suspend(response.reject_interval)
      when 401, 403
        warn { sprintf("Insights Event send failed: %s Dropping queued events and rejecting new ones for %ss. code=%s", response.error_message, response.reject_interval, response.code) }
        suspend(response.reject_interval)
      when 413
        warn { sprintf("Insights Event send failed: Payload is too large. code=%s", response.code) }
      when 201
        debug { sprintf("Success ⚡ Insights Event sent code=%s", response.code) }
      when :stubbed
        debug { "Success ⚡ Development mode is enabled; This event will be sent after app is deployed." }
      when :error
        warn { sprintf("Insights Event send failed: an unknown error occurred. code=%s error=%s", response.code, response.message.to_s.dump) }
      else
        warn { sprintf("Insights Event send failed: unknown response from server. code=%s", response.code) }
      end
    end

    # Release every waiting flush. Important to perform during cleanup when
    # shutting down, otherwise they could end up waiting indefinitely.
    def release_marker
      if mutex.owned?
        marker.broadcast
      else
        mutex.synchronize { marker.broadcast }
      end
    end

    def signal_marker(marker)
      if mutex.owned?
        marker.signal
      else
        mutex.synchronize { marker.signal }
      end
    end
  end
end
