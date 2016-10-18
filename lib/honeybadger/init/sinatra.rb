require 'honeybadger/ruby'

module Honeybadger
  module Init
    module Sinatra
      ::Sinatra::Base.class_eval do
        class << self
          def build_with_honeybadger(*args, &block)
            install_honeybadger
            build_without_honeybadger(*args, &block)
          end
          alias :build_without_honeybadger :build
          alias :build :build_with_honeybadger

          def honeybadger_config(app)
            {
              api_key: defined?(honeybadger_api_key) ? honeybadger_api_key : nil
            }
          end

          def install_honeybadger
            Honeybadger::Agent.instance.init!(honeybadger_config(self))
            Honeybadger::Agent.load_plugins!

            config = Honeybadger.config
            return unless config[:'sinatra.enabled']

            install_honeybadger_middleware(Honeybadger::Rack::ErrorNotifier, config) if config.feature?(:notices) && config[:'exceptions.enabled']
          end

          def install_honeybadger_middleware(klass, config)
            return if middleware.any? {|m| m[0] == klass }
            use(klass, config)
          end
        end
      end
    end
  end
end
