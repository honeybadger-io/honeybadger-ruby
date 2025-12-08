require "honeybadger/notification_subscriber"

module Honeybadger
  module Plugins
    module Flipper
      Plugin.register :flipper do
        requirement { defined?(::Flipper) }
        requirement { defined?(::ActiveSupport::Notifications) }

        execution do
          if config.load_plugin_insights?(:flipper)
            ::ActiveSupport::Notifications.subscribe(
              "feature_operation.flipper",
              Honeybadger::FlipperSubscriber.new
            )
          end
        end
      end
    end
  end
end

module Honeybadger
  class FlipperSubscriber < NotificationSubscriber
    def format_payload(_name, payload)
      payload.slice(:feature_name, :operation, :result)
    end

    def record(name, payload)
      Honeybadger.event(name, payload)
    end
  end
end
