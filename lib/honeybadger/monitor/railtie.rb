module Honeybadger
  module Monitor
    class Railtie < ::Rails::Railtie

      config.after_initialize do
        if Honeybadger.configuration.traces?
          ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |name, started, finished, id, data|
            Trace.create(id)
          end

          ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            Monitor.worker.trace.add_query(event) if Monitor.worker.trace and event.name != 'SCHEMA'
          end

          ActiveSupport::Notifications.subscribe(/^render_(template|action|collection)\.action_view/) do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            Monitor.worker.trace.add(event) if Monitor.worker.trace
          end

          ActiveSupport::Notifications.subscribe('net_http.request') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            Monitor.worker.trace.add(event) if Monitor.worker.trace
          end

          ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            if event.payload[:controller] && event.payload[:action] && Monitor.worker.trace
              Monitor.worker.trace.complete(event)
            end
          end
        end

        if Honeybadger.configuration.metrics?
          ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            status = event.payload[:exception] ? 500 : event.payload[:status]
            Monitor.worker.timing("app.request.#{status}", event.duration)

            controller = event.payload[:controller]
            action = event.payload[:action]
            if controller && action
              Monitor.worker.timing("app.controller.#{controller}.#{action}.total", event.duration)
              Monitor.worker.timing("app.controller.#{controller}.#{action}.view", event.payload[:view_runtime]) if event.payload[:view_runtime]
              Monitor.worker.timing("app.controller.#{controller}.#{action}.db", event.payload[:db_runtime]) if event.payload[:db_runtime]
            end
          end
        end
      end

    end
  end
end
