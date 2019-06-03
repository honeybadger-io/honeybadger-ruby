require 'honeybadger/plugin'
require 'honeybadger/breadcrumbs/logging'

module Honeybadger
  module Plugins
    class Breadcrumbs
      def self.send_breadcrumb_notification(name, duration, notification_config, data = {})
        return if notification_config[:exclude_when] && notification_config[:exclude_when].call(data)

        data[:duration] = duration
        data = notification_config[:transform].call(data) if notification_config[:transform]

        Honeybadger.add_breadcrumb(
          notification_config[:message] || name,
          category: notification_config[:category] || :custom,
          metadata: data
        )
      end

      def self.subscribe_to_notification(name, notification_config)
        ActiveSupport::Notifications.subscribe(name) do |_, started, finished, _, data|
          send_breadcrumb_notification(name, finished - started, notification_config, data)
        end
      end
    end

    Plugin.register :breadcrumbs do
      requirement { config[:'breadcrumbs.enabled'] }

      execution do
        # Rails specific breadcrumb events
        #
        if defined?(::Rails.application) && ::Rails.application
          config[:'breadcrumbs.active_support_notifications'].each do |name, config|
            Breadcrumbs.subscribe_to_notification(name, config)
          end
          ActiveSupport::LogSubscriber.prepend(Honeybadger::Breadcrumbs::LogSubscriberInjector)
        end

        ::Logger.prepend(Honeybadger::Breadcrumbs::LogWrapper)
      end
    end
  end
end
