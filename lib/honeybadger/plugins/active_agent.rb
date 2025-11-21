require "honeybadger/plugin"
require "honeybadger/ruby"
require "honeybadger/notification_subscriber"

module Honeybadger
  Plugin.register :active_agent do
    requirement { defined?(::ActiveAgent) }

    execution do
      next unless Honeybadger.config[:"exceptions.enabled"]

      # TODO: what's the best way to subscribe to unhandled errors, and how can
      # we test them?
      # Honeybadger.notify(error, context: {
      #   # TODO: what context should we include?
      # })
    end

    execution do
      if config.load_plugin_insights?(:active_agent)
        # TODO: do we want to subscribe to .provider.active_agent events for
        # individual API calls in multi-turn conversions? If so, we may want to
        # unsubscribe from prompt.active_agent and embed.active_agent events to
        # avoid duplicates. I'm not sure if that would prevent us from showing
        # the total duration for prompts, though.
        ::ActiveSupport::Notifications.subscribe(/(prompt|embed|stream_open|stream_close|stream_chunk|tool_call|process)\.active_agent/, Honeybadger::ActiveJobSubscriber.new)
      end
    end
  end
end
