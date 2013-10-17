module Honeybadger
  module Monitor
    class Railtie < ::Rails::Railtie

      config.after_initialize do
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
