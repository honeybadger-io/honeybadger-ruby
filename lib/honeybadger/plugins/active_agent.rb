require "honeybadger/plugin"
require "honeybadger/notification_subscriber"

module Honeybadger
  module Plugins
    module ActiveAgent

      Plugin.register :active_agent do
        requirement { defined?(::ActiveAgent) }
        requirement { defined?(::ActiveSupport::Notifications) }

        execution do
          if config.load_plugin_insights?(:active_agent)
            ::ActiveSupport::Notifications.subscribe(
              /(prompt|embed|stream_open|stream_close|tool_call|process)\.active_agent/,
              Honeybadger::ActiveAgentSubscriber.new
            )
          end
        end
      end
    end
  end
end

module Honeybadger
  class ActiveAgentSubscriber < NotificationSubscriber
  end
end
