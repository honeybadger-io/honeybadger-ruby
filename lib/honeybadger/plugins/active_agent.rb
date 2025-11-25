require "honeybadger/plugin"
require "honeybadger/ruby"
require "honeybadger/notification_subscriber"

module Honeybadger
  Plugin.register :active_agent do
    requirement { defined?(::ActiveAgent) }

    execution do
      if config.load_plugin_insights?(:active_agent)
        # TODO: NotificationSubscriber may be the wrong thing to use here, or we may want to subclass it.
        ::ActiveSupport::Notifications.subscribe(/(prompt|embed|stream_open|stream_close|stream_chunk|tool_call|process|provider)\.active_agent/, Honeybadger::NotificationSubscriber.new)
      end
    end
  end
end
