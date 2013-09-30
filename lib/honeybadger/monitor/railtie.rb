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

          ActiveSupport::Notifications.subscribe(/render_(partial|template)\.action_view\Z/) do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            if !event.name.start_with?('!')
              metric = event.name.split('.').first
              file = event.payload[:identifier].gsub(::Rails.root.to_s + File::SEPARATOR,'').gsub('.', '_')
              Monitor.worker.timing("app.view.#{metric}.#{file}", event.duration)
            end
          end

          ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            if event.name != 'SCHEMA' && !event.name == 'CACHE'
              metric = event.payload[:sql].strip.split(' ', 2).first.downcase
              Monitor.worker.timing("app.active_record.#{metric}", event.duration)
            end
          end

          ActiveSupport::Notifications.subscribe(/(deliver|receive).action_mailer\Z/) do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            if !event.name.start_with?('!')
              metric = event.name.split('.').first
              Monitor.worker.timing("app.mail.#{metric}", event.duration)
            end
          end

        end
      end

    end
  end
end
