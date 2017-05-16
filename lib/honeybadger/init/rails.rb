require 'rails'
require 'yaml'

require 'honeybadger/ruby'

module Honeybadger
  module Init
    module Rails
      class Railtie < ::Rails::Railtie
        rake_tasks do
          load 'honeybadger/tasks.rb'
        end

        initializer 'honeybadger.install_middleware' do |app|
          app.config.middleware.insert(0, Honeybadger::Rack::ErrorNotifier)
          app.config.middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserInformer) if Honeybadger.config[:'user_informer.enabled']
          app.config.middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserFeedback) if Honeybadger.config[:'feedback.enabled']
        end

        config.after_initialize do
          Honeybadger.init!({
            :root           => ::Rails.root.to_s,
            :env            => ::Rails.env,
            :'config.path'  => ::Rails.root.join('config', 'honeybadger.yml'),
            :logger         => Logging::FormattedLogger.new(::Rails.logger),
            :framework      => :rails
          })
          Honeybadger.load_plugins!
        end
      end
    end
  end
end
