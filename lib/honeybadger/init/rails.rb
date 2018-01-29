require 'rails'
require 'yaml'

require 'honeybadger/ruby'

module Honeybadger
  module Init
    module Rails
      class Railtie < ::Rails::Railtie

        def self.rails_init(context)
          return if Honeybadger::Lock.initialized?
          opts = {
            with_env: {logger: ::Rails.logger},
            without_env: {logger: Logger.new(STDOUT)}
          }
          Honeybadger.init!({
            :root           => ::Rails.root.to_s,
            :env            => ::Rails.env,
            :'config.path'  => ::Rails.root.join('config', 'honeybadger.yml'),
            :logger         => Logging::FormattedLogger.new(opts[context][:logger]),
            :framework      => :rails
          })
          Honeybadger.load_plugins!
        end

        rake_tasks do
          load 'honeybadger/tasks.rb'
        end

        initializer 'honeybadger.install_middleware' do |app|
          app.config.middleware.insert(0, Honeybadger::Rack::ErrorNotifier)
          app.config.middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserInformer)
          app.config.middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserFeedback)
        end

        config.after_initialize do
          ::Honeybadger::Init::Rails::Railtie.rails_init(:with_env)
        end
      end
    end
  end
end

Honeybadger.install_at_exit_callback
