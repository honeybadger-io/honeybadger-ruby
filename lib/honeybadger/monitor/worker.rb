require "singleton"

module Honeybadger
  module Monitor
    class Worker
      include Singleton

      # Sub-class thread so we have a named thread (useful for debugging in Thread.list).
      class MetricsThread < Thread
      end

      def initialize
        init_metrics
        init_traces
        @delay = defined?(::Rails) && ::Rails.env.development? ? 10 : 60
        @per_request = 100
        @traces_per_request = 20
        @sender = Monitor::Sender.new(Honeybadger.configuration)
        @lock = Mutex.new
        start
        at_exit { stop }
      end

      def start
        Honeybadger.write_verbose_log('Starting worker')

        @thread = MetricsThread.new do
          begin
            until Thread.current[:should_exit] do
              send_metrics
              send_traces
              sleep @delay
            end
          rescue Exception => e
            Honeybadger.write_verbose_log("Error in MetricsThread (shutting down): #{e.class} - #{e.message}\n#{e.backtrace.join("\n\t")}", :error)
            raise e
          end
        end
      end

      def stop
        Honeybadger.write_verbose_log('Stopping worker')
        @thread[:should_exit] = true if @thread
      end

      def fork
        Honeybadger.write_verbose_log('Forking worker')

        stop

        @lock.unlock if @lock.locked?
        @lock.synchronize do
          init_metrics
          init_traces
        end

        start
      end

      def timing(name, value)
        add_metric(name, value, :timing)
      end

      def increment(name, value)
        add_metric(name, value, :counter)
      end

      def pending_traces
        @pending_traces ||= {}
      end

      def trace
        Thread.current[:hb_trace_id] ? @pending_traces[Thread.current[:hb_trace_id]] : nil
      end

      def queue_trace
        return unless trace

        @lock.synchronize do
          if trace.duration > Honeybadger.configuration.trace_threshold && (!@traces[trace.key] || @traces[trace.key].duration < trace.duration)
            @traces[trace.key] = trace
          end
          @pending_traces[Thread.current[:hb_trace_id]] = nil
          Thread.current[:hb_trace_id] = nil
        end
      end

      protected

        def init_metrics
          @metrics = { :timing => {}, :counter => {} }
        end

        def init_traces
          @traces = {}
        end

        def collect_metrics
          @lock.synchronize do
            metrics = @metrics
            init_metrics
            metrics
          end
        end

        def collect_traces
          @lock.synchronize do
            traces = @traces.values
            init_traces
            traces
          end
        end

        def send_metrics
          metrics = collect_metrics
          return unless metrics[:timing].any? || metrics[:counter].any?

          Honeybadger.write_verbose_log('Sending metrics')

          [].tap do |m|
            metrics[:counter].each do |metric, values|
              m << "#{metric} #{values.sum}"
            end
            metrics[:timing].each do |metric, values|
              m << "#{metric}:mean #{values.mean}"
              m << "#{metric}:median #{values.median}"
              m << "#{metric}:percentile_90 #{values.percentile(90)}"
              m << "#{metric}:min #{values.min}"
              m << "#{metric}:max #{values.max}"
              m << "#{metric}:stddev #{values.standard_dev}" if values.count > 1
              m << "#{metric} #{values.count}"
            end
          end.each_slice(@per_request) do |mm|
            begin
              @sender.send_metrics({ :metrics => mm.compact, :environment => Honeybadger.configuration.environment_name, :hostname => Honeybadger.configuration.hostname })
            rescue Exception => e
              log(:error, "[Honeybadger::Monitor::Worker#send_metrics] Failed to send #{mm.count} metrics: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
            end
          end
        end

        def send_traces
          traces = collect_traces
          return unless traces.any?

          Honeybadger.write_verbose_log('Sending traces')

          traces.each_slice(@traces_per_request) do |t|
            begin
              @sender.send_traces({ :traces => t.compact.map(&:to_h), :environment => Honeybadger.configuration.environment_name, :hostname => Honeybadger.configuration.hostname })
            rescue Exception => e
              log(:error, "[Honeybadger::Monitor::Worker#send_traces] Failed to send #{t.count} metrics: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
            end
          end
        end

        def add_metric(name, value, kind)
          @lock.synchronize do
            (@metrics[kind][name] ||= Honeybadger::Array.new) << value
          end
        end

        def log(level, message)
          Honeybadger.write_verbose_log(message, level)
        end

    end
  end
end
