module Honeybadger
  module Rack
    class MetricsReporter
      def initialize(app, config)
        @app = app
        config.logger.warn('DEPRECATION WARNING: `Honeybadger::Rack::MetricsReporter` no longer has any effect and will be removed.')
      end

      def call(env)
        @app.call(env)
      end
    end
  end
end
