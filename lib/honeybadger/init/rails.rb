require "rails"
require "yaml"

require "honeybadger/ruby"

module Honeybadger
  module Init
    module Rails
      class Railtie < ::Rails::Railtie
        rake_tasks do
          load "honeybadger/tasks.rb"
        end

        initializer "honeybadger.install_middleware" do |app|
          honeybadger_config = Honeybadger::Agent.instance.config

          if honeybadger_config[:"exceptions.enabled"]
            app.config.middleware.insert(0, Honeybadger::Rack::ErrorNotifier)
            app.config.middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserInformer) if honeybadger_config[:"user_informer.enabled"]
            app.config.middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserFeedback) if honeybadger_config[:"feedback.enabled"]
          end
        end

        config.before_initialize do
          Honeybadger.init!({
            root: ::Rails.root.to_s,
            env: ::Rails.env,
            "config.path": ::Rails.root.join("config", "honeybadger.yml"),
            logger: Logging::FormattedLogger.new(::Rails.logger),
            framework: :rails
          })
        end

        config.after_initialize do
          Honeybadger.load_plugins!
        end

        console do
          unless (Honeybadger::Agent.instance.config[:"insights.enabled"] = Honeybadger::Agent.instance.config[:"insights.console.enabled"])
            Honeybadger::Agent.instance.config.logger.debug("Rails console detected, shutting down Honeybadger Insights workers.")
            Honeybadger::Agent.instance.stop_insights
          end
        end
      end
    end
  end
end

Honeybadger.install_at_exit_callback
