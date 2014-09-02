require 'honeybadger'

module Honeybadger
  module Rack
    class MetricsReporter
      GC_TIME_METRIC = 'app.gc.time'.freeze
      GC_COLLECTIONS_METRIC = 'app.gc.collections'.freeze

      def initialize(app, config)
        @app = app
        @config = config
      end

      def call(env)
        start = Time.now
        track_gc? and GC::Profiler.clear
        status, headers, body = app.call(env)
        duration = (Time.now - start) * 1000
        report_metrics(status, duration)
        [status, headers, body]
      end

      private

      attr_reader :app, :config

      def track_gc?
        config[:'metrics.gc_profiler']
      end

      def report_metrics(status, duration)
        Agent.timing("app.request.#{status}", duration)

        if track_gc? && GC::Profiler.total_time > 0
          Agent.timing(GC_TIME_METRIC, GC::Profiler.total_time * 1000)
          Agent.increment(GC_COLLECTIONS_METRIC, GC::Profiler.result[/\d+/].to_i)
        end
      end
    end
  end
end
