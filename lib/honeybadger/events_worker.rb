require 'forwardable'
require 'net/http'

require 'honeybadger/logging'

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

    # The base number for the exponential backoff formula when calculating the
    # throttle interval. `1.05 ** throttle` will reach an interval of 2 minutes
    # after around 100 429 responses from the server.
    BASE_THROTTLE = 1.05

    # TODO: These could be configurable?

    def initialize(config)
      @config = config
      @throttle = 0
      @throttle_interval = 0
      @mutex = Mutex.new
      @marker = ConditionVariable.new
      @queue = Queue.new
      @send_queue = Queue.new
      @shutdown = false
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
      d { 'shutting down events worker' }

      mutex.synchronize do
        @shutdown = true
      end

      return true if force
      return true unless thread&.alive?

      if throttled?
        warn { sprintf('Unable to send %s event(s) to Honeybadger (currently throttled)', queue.size) } unless queue.empty?
        return true
      end

      info { sprintf('Waiting to send %s events(s) to Honeybadger', queue.size) } unless queue.empty?
      queue.push(FLUSH)
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
          queue.push(FLUSH)
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
        @timeout_thread = Thread.new { schedule_timeout_check }
      end

      true
    end

    private

    attr_reader :config, :queue, :pid, :mutex, :marker, :thread, :timeout_thread, :throttle,
      :throttle_interval, :start_at, :send_queue, :last_sent

    def_delegator :config, :backend

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

    def throttled?
      mutex.synchronize { throttle > 0 }
    end

    def kill!
      d { 'killing worker thread' }

      if thread
        Thread.kill(thread)
        Thread.kill(timeout_thread)
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

    def schedule_timeout_check
      loop do
        sleep(config.events_timeout / 1000.0)
        queue.push(CHECK_TIMEOUT)
      end
    end

    def run
      begin
        d { 'worker started' }
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
      send_now(mutex.synchronize { send_queue })
      mutex.synchronize do
        @last_sent = Time.now
        debug { sprintf('Sending %s events', send_queue.length) }
        send_queue.clear
        if @dropped_events > 0
          warn { sprintf('Dropped %s messages due to exceeding max queue size of %s', @dropped_events, config.events_max_queue_size) }
        end
        @dropped_events = 0
      end
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
    rescue StandardError => e
      error {
        msg = "Error in worker thread class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    end

    def work(msg)
      enqueue_msg(msg)
      check_and_send

      if shutdown? && throttled?
        warn { sprintf('Unable to send %s events(s) to Honeybadger (currently throttled)', queue.size) } if queue.size > 1
        kill!
        return
      end

      sleep(throttle_interval)
    rescue StandardError => e
      error {
        msg = "Error in worker thread class=%s message=%s\n\t%s"
        sprintf(msg, e.class, e.message.dump, Array(e.backtrace).join("\n\t"))
      }
    end


    def send_to_backend(msg)
      d { 'events_worker sending to backend' }
      response = backend.event(msg)
      response
    end

    def calc_throttle_interval
      ((BASE_THROTTLE ** throttle) - 1).round(3)
    end

    def inc_throttle
      mutex.synchronize do
        @throttle += 1
        @throttle_interval = calc_throttle_interval
        throttle
      end
    end

    def dec_throttle
      mutex.synchronize do
        return nil if throttle == 0
        @throttle -= 1
        @throttle_interval = calc_throttle_interval
        throttle
      end
    end

    def handle_response(response)
      d { sprintf('events_worker response code=%s message=%s', response.code, response.message.to_s.dump) }

      case response.code
      when 429, 503
        throttle = inc_throttle
        warn { sprintf('Event send failed: project is sending too many events. code=%s throttle=%s interval=%s', response.code, throttle, throttle_interval) }
      when 402
        warn { sprintf('Event send failed: payment is required. code=%s', response.code) }
        suspend(3600)
      when 403
        warn { sprintf('Event send failed: API key is invalid. code=%s', response.code) }
        suspend(3600)
      when 413
        warn { sprintf('Event send failed: Payload is too large. code=%s', response.code) }
      when 201
        if throttle = dec_throttle
          debug { sprintf('Success ⚡ Event sent code=%s throttle=%s interval=%s', response.code, throttle, throttle_interval) }
        else
          debug { sprintf('Success ⚡ Event sent code=%s', response.code) }
        end
      when :stubbed
        info { sprintf('Success ⚡ Development mode is enabled; This event will be sent after app is deployed.') }
      when :error
        warn { sprintf('Event send failed: an unknown error occurred. code=%s error=%s', response.code, response.message.to_s.dump) }
      else
        warn { sprintf('Event send failed: unknown response from server. code=%s', response.code) }
      end
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
