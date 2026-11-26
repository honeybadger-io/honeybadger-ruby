require "honeybadger/plugin"
require "honeybadger/notification_subscriber"

module Honeybadger
  module Plugins
    module RubyLLM
      Plugin.register :ruby_llm do
        requirement { defined?(::RubyLLM) }
        requirement { defined?(::ActiveSupport::Notifications) }

        execution do
          if config.load_plugin_insights?(:ruby_llm)
            class_name = config[:"ruby_llm.insights.subscriber"].to_s.strip
            subscriber = if class_name.empty?
              Honeybadger::RubyLLMSubscriber.new
            else
              begin
                candidate = Object.const_get(class_name).new
                unless candidate.respond_to?(:start) && candidate.respond_to?(:finish)
                  raise TypeError, "does not respond to #start and #finish"
                end
                candidate
              rescue => e
                logger.error("Unable to load ruby_llm.insights.subscriber=#{class_name} (#{e.class}: #{e.message}); falling back to Honeybadger::RubyLLMSubscriber")
                Honeybadger::RubyLLMSubscriber.new
              end
            end

            # request.ruby_llm is intentionally excluded: it fires for every
            # provider HTTP request (including retries and streams) and
            # duplicates chat-level metadata.
            ::ActiveSupport::Notifications.subscribe(
              /(chat|tool_call|embedding|image|moderation|transcription|models\.refresh)\.ruby_llm/,
              subscriber
            )
          end
        end
      end
    end
  end
end

module Honeybadger
  class RubyLLMSubscriber < NotificationSubscriber
    # RubyLLM 2 replaced the flat token keys with RubyLLM::Tokens objects.
    # Maps the RubyLLM 1 key names, which stay the event fields, to its
    # readers.
    TOKEN_READERS = {
      input_tokens: :input,
      output_tokens: :output,
      cached_tokens: :cache_read,
      cache_creation_tokens: :cache_write,
      thinking_tokens: :thinking
    }.freeze

    # Payloads carry full Ruby objects (chat, messages, responses, tool
    # arguments, inputs), which may contain sensitive content. Allow only
    # scalar metadata through.
    def format_payload(name, payload)
      case name
      when "chat.ruby_llm"
        # :response_tokens (RubyLLM >= 2.1) is the usage of this model call.
        # :tokens can also include earlier fallback attempts, which have
        # their own events.
        payload.slice(:provider, :provider_class, :model, :message_count, :temperature, :tool_choice, :tool_call_limit, :streaming, :response_model, :response_role, :tool_call, :input_tokens, :output_tokens, :cached_tokens, :cache_creation_tokens, :thinking_tokens, :exception)
          .merge(token_counts(payload[:response_tokens] || payload[:tokens], :input_tokens, :output_tokens, :cached_tokens, :cache_creation_tokens, :thinking_tokens))
      when "tool_call.ruby_llm"
        payload.slice(:provider, :provider_class, :model, :tool_name, :tool_call_id, :result_class, :exception)
      when "embedding.ruby_llm"
        payload.slice(:provider, :provider_class, :model, :dimensions, :response_model, :input_tokens, :embedding_dimensions, :embedding_count, :exception)
          .merge(token_counts(payload[:tokens], :input_tokens))
      when "image.ruby_llm"
        payload.slice(:provider, :provider_class, :model, :size, :response_model, :exception)
      when "moderation.ruby_llm"
        payload.slice(:provider, :provider_class, :model, :flagged, :exception)
      when "transcription.ruby_llm"
        payload.slice(:provider, :provider_class, :model, :language, :response_model, :input_tokens, :output_tokens, :exception)
          .merge(token_counts(payload[:tokens], :input_tokens, :output_tokens))
      when "models.refresh.ruby_llm"
        payload.slice(:remote_only, :model_count, :exception)
      else
        payload.slice(:provider, :provider_class, :model, :exception)
      end
    end

    private

    # Only the counts go through, never the tokens object itself. RubyLLM 1
    # payloads have no tokens object and keep their flat keys.
    def token_counts(tokens, *keys)
      keys.each_with_object({}) do |key, counts|
        reader = TOKEN_READERS.fetch(key)
        next unless tokens.respond_to?(reader)

        count = tokens.public_send(reader)
        counts[key] = count unless count.nil?
      end
    end
  end
end
