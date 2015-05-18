require 'rails'
require 'yaml'

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
                middleware.insert(0, 'Honeybadger::Rack::ErrorNotifier', config)
                middleware.insert_before('Honeybadger::Rack::ErrorNotifier', 'Honeybadger::Rack::UserFeedback', config)
                middleware.insert_before('Honeybadger::Rack::UserFeedback', 'Honeybadger::Rack::UserInformer', config)
              end
            end

            if config.feature?(:traces) && config[:'traces.enabled']
              ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |name, started, finished, id, data|
                Trace.create(id)
              end

              ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                Trace.current.add_query(event) if Trace.current and event.name != 'SCHEMA'
              end

              ActiveSupport::Notifications.subscribe(/^render_(template|partial|action|collection)\.action_view/) do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                Trace.current.add(event) if Trace.current
              end

              ActiveSupport::Notifications.subscribe('net_http.request') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                Trace.current.add(event) if Trace.current
              end

              ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                if Trace.current && event.payload[:controller] && event.payload[:action]
                  Trace.current.complete(event, config)
                end
              end
            end

            if config.feature?(:metrics) && config[:'metrics.enabled']
              ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                status = event.payload[:exception] ? 500 : event.payload[:status]
                Agent.timing("app.request.#{status}", event.duration)
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
