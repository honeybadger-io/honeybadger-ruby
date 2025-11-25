require "honeybadger/plugin"
require "honeybadger/ruby"
require "honeybadger/notification_subscriber"

module Honeybadger
  Plugin.register :active_agent do
    requirement { defined?(::ActiveAgent) }

    execution do
      if config.load_plugin_insights?(:active_agent)
        ::ActiveSupport::Notifications.subscribe(/(prompt|embed|stream_open|stream_close|stream_chunk|tool_call|process)\.active_agent/, Honeybadger::ActiveJobSubscriber.new)
      end
    end
  end
end
