require "honeybadger/plugin"

module Honeybadger
  module Plugins
    module RubyLLM
      module ProviderInstrumentation
        def complete(messages, tools:, temperature:, model:, **kwargs, &block)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = super
          duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)

          payload = {
            event_type: "complete.ruby_llm",
            duration: duration,
            provider: slug,
            model: model.id,
            stream: !block.nil?,
            temperature: temperature,
            tool_count: tools.size,
            message_count: messages.size
          }

          if response.respond_to?(:tokens) && response.tokens
            tokens = response.tokens
            payload[:input_tokens] = tokens.input
            payload[:output_tokens] = tokens.output
            payload[:cached_tokens] = tokens.cached
            payload[:thinking_tokens] = tokens.thinking
          end

          if response.respond_to?(:tool_calls) && response.tool_calls
            payload[:tool_call_count] = response.tool_calls.size
          end

          Honeybadger.event(payload)
          response
        end

        def embed(text, model:, dimensions:)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = super
          duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)

          payload = {
            event_type: "embed.ruby_llm",
            duration: duration,
            provider: slug,
            model: model
          }

          payload[:input_tokens] = response.input_tokens if response.respond_to?(:input_tokens)

          Honeybadger.event(payload)
          response
        end

        def paint(prompt, model:, size:)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = super
          duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)

          Honeybadger.event(
            event_type: "paint.ruby_llm",
            duration: duration,
            provider: slug,
            model: model,
            size: size
          )
          response
        end

        def transcribe(audio_file, model:, language:, **options)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = super
          duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)

          Honeybadger.event(
            event_type: "transcribe.ruby_llm",
            duration: duration,
            provider: slug,
            model: model,
            language: language
          )
          response
        end
      end

      module ChatInstrumentation
        private

        def execute_tool(tool_call)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = super
          duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)

          Honeybadger.event(
            event_type: "tool_call.ruby_llm",
            duration: duration,
            tool_name: tool_call.name
          )
          result
        end
      end

      Plugin.register :ruby_llm do
        requirement { defined?(::RubyLLM::Provider) }

        execution do
          if config.load_plugin_insights?(:ruby_llm)
            ::RubyLLM::Provider.prepend(ProviderInstrumentation)
            ::RubyLLM::Chat.prepend(ChatInstrumentation)
          end
        end
      end
    end
  end
end
