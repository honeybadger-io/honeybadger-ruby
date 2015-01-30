module Honeybadger
  module Init
    module Sinatra
      ::Sinatra::Base.class_eval do
        class << self
          def build_with_honeybadger(*args, &block)
            config = Honeybadger::Config.new(honeybadger_config(self))
            if Honeybadger.start(config)
              use(Honeybadger::Rack::ErrorNotifier, config) if config.feature?(:notices) && config[:'exceptions.enabled']
              use(Honeybadger::Rack::MetricsReporter, config) if config.feature?(:metrics) && config[:'metrics.enabled']
            end

            build_without_honeybadger(*args, &block)
          end
          alias :build_without_honeybadger :build
          alias :build :build_with_honeybadger

          def honeybadger_config(app)
            {
              api_key: defined?(honeybadger_api_key) ? honeybadger_api_key : nil
            }
          end
        end
      end
    end
  end
end
