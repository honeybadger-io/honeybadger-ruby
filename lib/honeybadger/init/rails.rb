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
          honeybadger_config = Honeybadger::Agent.instance.config

          app.config.middleware.insert(0, Honeybadger::Rack::ErrorNotifier)
          app.config.middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserInformer) if honeybadger_config[:'user_informer.enabled']
          app.config.middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserFeedback) if honeybadger_config[:'feedback.enabled']
        end

        config.before_initialize do
          Honeybadger.init!({
            :root           => ::Rails.root.to_s,
            :env            => ::Rails.env,
            :'config.path'  => ::Rails.root.join('config', 'honeybadger.yml'),
            :logger         => Logging::FormattedLogger.new(::Rails.logger),
            :framework      => :rails
          })
        end

        config.after_initialize do
          Honeybadger.load_plugins!
        end

        console do
          Honeybadger::Agent.instance.config[:'insights.enabled'] = false unless Honeybadger::Agent.instance.config.env.has_key?(:'insights.enabled')
        end
      end
    end
  end
end

Honeybadger.install_at_exit_callback
