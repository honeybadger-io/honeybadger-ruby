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
    def format_payload(name, payload)
      case name
      when "prompt.active_agent"
        payload.slice(:provider, :provider_module, :trace_id, :model, :message_count, :stream, :usage, :finish_reason, :response_model, :response_id, :temperature, :max_tokens, :top_p, :tool_count, :has_instructions)
      when "embed.active_agent"
        payload.slice(:provider, :provider_module, :trace_id, :model, :input_size, :embedding_count, :usage, :response_model, :response_id, :encoding_format, :dimensions)
      else
        payload
      end
    end
  end
end
