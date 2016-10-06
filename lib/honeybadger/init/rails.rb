require 'rails'

module Honeybadger
  module Init
    module Rails
      class Railtie < ::Rails::Railtie
        rake_tasks do
          load 'honeybadger/tasks.rb'
        end

        initializer 'honeybadger.install' do
          config = Config.new(local_config)
          if Honeybadger.start(config)
            if config.feature?(:notices) && config[:'exceptions.enabled']
              ::Rails.application.config.middleware.tap do |middleware|
                middleware.insert(0, Honeybadger::Rack::ErrorNotifier, config)
                middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserInformer, config) if config[:'user_informer.enabled']
                middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserFeedback, config) if config[:'feedback.enabled']
              end
            end
          end
        end

        private

        def local_config
          {
            :root           => ::Rails.root.to_s,
            :env            => ::Rails.env,
            :'config.path'  => ::Rails.root.join('config', 'honeybadger.yml'),
            :logger         => Logging::FormattedLogger.new(::Rails.logger),
            :framework      => :rails
          }
        end
      end
    end
  end
end
