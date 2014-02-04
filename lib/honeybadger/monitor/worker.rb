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
        @delay = 60
        @per_request = 100
        @sender = Monitor::Sender.new(Honeybadger.configuration)
        @lock = Mutex.new
        start
        at_exit { stop }
      end

      def start
        @thread = MetricsThread.new do
          until Thread.current[:should_exit] do
            send_metrics
            sleep @delay
          end
        end
      end

      def stop
        @thread[:should_exit] = true if @thread
      end

      def timing(name, value)
        add_metric(name, value, :timing)
      end

      def increment(name, value)
        add_metric(name, value, :counter)
      end

      protected

        def init_metrics
          @metrics = { :timing => {}, :counter => {} }
        end

        def collect_metrics
          @lock.synchronize do
            metrics = @metrics
            init_metrics
            metrics
          end
        end

        def send_metrics
          metrics = collect_metrics
          return unless metrics[:timing].any? || metrics[:counter].any?
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
