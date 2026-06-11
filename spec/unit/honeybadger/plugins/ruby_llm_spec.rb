require "honeybadger/plugins/ruby_llm"
require "honeybadger/config"

describe "RubyLLM Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:ruby_llm].reset!
  end

  context "when RubyLLM is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:ruby_llm].load!(config) }.not_to raise_error
    end
  end

  context "when RubyLLM is installed", if: defined?(::ActiveSupport::Notifications) do
    let(:ruby_llm_shim) do
      Module.new
    end

    before do
      Object.const_set(:RubyLLM, ruby_llm_shim)
    end

    after { Object.send(:remove_const, :RubyLLM) }

    context "when insights are enabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": true) }
      let(:subscriber) { instance_double(Honeybadger::RubyLLMSubscriber) }

      before do
        allow(Honeybadger::RubyLLMSubscriber).to receive(:new).and_return(subscriber)
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "subscribes to RubyLLM notifications" do
        expect(ActiveSupport::Notifications).to receive(:subscribe).with(
          match("chat.ruby_llm"),
          subscriber
        )
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)
      end

      it "subscribes with a pattern that matches all expected events" do
        pattern = nil
        allow(ActiveSupport::Notifications).to receive(:subscribe) { |p, _| pattern = p }
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)

        expect(pattern).to match("chat.ruby_llm")
        expect(pattern).to match("tool_call.ruby_llm")
        expect(pattern).to match("embedding.ruby_llm")
        expect(pattern).to match("image.ruby_llm")
        expect(pattern).to match("moderation.ruby_llm")
        expect(pattern).to match("transcription.ruby_llm")
        expect(pattern).to match("models.refresh.ruby_llm")
        expect(pattern).not_to match("request.ruby_llm")
      end
    end

    context "when a custom subscriber is configured" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": true, "ruby_llm.insights.subscriber": "CustomRubyLLMSubscriber") }

      let(:custom_subscriber_class) do
        Class.new(Honeybadger::RubyLLMSubscriber) do
          def format_payload(name, payload)
            super.merge(tenant: payload.dig(:chat, :tenant))
          end
        end
      end

      let(:subscribed) do
        subscriber = nil
        allow(ActiveSupport::Notifications).to receive(:subscribe) { |_, s| subscriber = s }
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)
        subscriber
      end

      before do
        # The constant is only defined during the example (long after the
        # plugin file is required), so resolution must happen lazily at
        # plugin execution time for these to pass.
        stub_const("CustomRubyLLMSubscriber", custom_subscriber_class)
      end

      it "subscribes an instance of the configured class" do
        expect(subscribed).to be_a(CustomRubyLLMSubscriber)
      end

      it "emits events formatted by the custom subscriber" do
        allow(Honeybadger).to receive(:event)

        payload = {provider: "openai", model: "gpt-4o-mini", chat: {tenant: "acme"}}
        subscribed.start("chat.ruby_llm", "abc123", payload)
        subscribed.finish("chat.ruby_llm", "abc123", payload)

        expect(Honeybadger).to have_received(:event).with("chat.ruby_llm", hash_including(model: "gpt-4o-mini", tenant: "acme"))
        expect(Honeybadger).to have_received(:event).with("chat.ruby_llm", hash_excluding(:chat))
      end

      context "when the custom subscriber gates events via process?" do
        let(:custom_subscriber_class) do
          Class.new(Honeybadger::RubyLLMSubscriber) do
            def process?(name, payload)
              payload[:tools].nil?
            end
          end
        end

        it "does not emit gated events" do
          allow(Honeybadger).to receive(:event)

          payload = {provider: "openai", model: "gpt-4o-mini", tools: [:weather]}
          subscribed.start("chat.ruby_llm", "abc123", payload)
          subscribed.finish("chat.ruby_llm", "abc123", payload)

          expect(Honeybadger).not_to have_received(:event)
        end
      end

      context "when the configured value is the class itself" do
        let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": true, "ruby_llm.insights.subscriber": CustomRubyLLMSubscriber) }

        it "subscribes an instance of that class" do
          expect(subscribed).to be_a(CustomRubyLLMSubscriber)
        end
      end

      context "when the configured value is blank" do
        let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": true, "ruby_llm.insights.subscriber": "") }

        it "subscribes the default subscriber without logging an error" do
          allow(config.logger).to receive(:error)

          expect(subscribed).to be_an_instance_of(Honeybadger::RubyLLMSubscriber)
          expect(config.logger).not_to have_received(:error)
        end
      end

      context "when the configured class cannot be resolved" do
        let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": true, "ruby_llm.insights.subscriber": "Nonexistent::Subscriber") }

        it "logs an error and subscribes the default subscriber" do
          allow(config.logger).to receive(:error)

          expect(subscribed).to be_an_instance_of(Honeybadger::RubyLLMSubscriber)
          expect(config.logger).to have_received(:error).with(/Nonexistent::Subscriber.*NameError/)
        end
      end

      context "when the configured constant cannot be instantiated" do
        let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": true, "ruby_llm.insights.subscriber": "CustomRubyLLMModule") }

        before { stub_const("CustomRubyLLMModule", Module.new) }

        it "logs the underlying error and subscribes the default subscriber" do
          allow(config.logger).to receive(:error)

          expect(subscribed).to be_an_instance_of(Honeybadger::RubyLLMSubscriber)
          expect(config.logger).to have_received(:error).with(/CustomRubyLLMModule.*NoMethodError/)
        end
      end

      context "when the configured class raises on instantiation" do
        let(:custom_subscriber_class) do
          Class.new(Honeybadger::RubyLLMSubscriber) do
            def initialize(dependency)
              super()
            end
          end
        end

        it "logs the underlying error and subscribes the default subscriber" do
          allow(config.logger).to receive(:error)

          expect(subscribed).to be_an_instance_of(Honeybadger::RubyLLMSubscriber)
          expect(config.logger).to have_received(:error).with(/CustomRubyLLMSubscriber.*ArgumentError/)
        end
      end
    end

    context "when insights are disabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": false) }

      before do
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "does not subscribe to notifications" do
        expect(ActiveSupport::Notifications).not_to receive(:subscribe)
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)
      end
    end

    context "when RubyLLM insights are disabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": false) }

      before do
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "does not subscribe to notifications" do
        expect(ActiveSupport::Notifications).not_to receive(:subscribe)
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)
      end
    end
  end
end

describe Honeybadger::RubyLLMSubscriber do
  let(:subscriber) { described_class.new }

  it "is a NotificationSubscriber" do
    expect(subscriber).to be_a(Honeybadger::NotificationSubscriber)
  end

  describe "#format_payload" do
    context "with chat.ruby_llm event" do
      it "excludes message content and object keys" do
        expect(
          subscriber.format_payload("chat.ruby_llm", {provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "gpt-4o-mini", message_count: 2, streaming: false, response_model: "gpt-4o-mini", input_tokens: 10, output_tokens: 20, chat: :object, model_info: :object, input_messages: :value, messages_after: :value, response: :value, tool_calls: :value, params: :value, schema: :value})
        ).to eq({provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "gpt-4o-mini", message_count: 2, streaming: false, response_model: "gpt-4o-mini", input_tokens: 10, output_tokens: 20})
      end
    end

    context "with tool_call.ruby_llm event" do
      it "excludes tool arguments and results" do
        expect(
          subscriber.format_payload("tool_call.ruby_llm", {provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "gpt-4o-mini", tool_name: "weather", tool_call_id: "1234", result_class: "String", chat: :object, model_info: :object, tool: :object, tool_call: :object, tool_arguments: :value, result: :value, result_content: :value})
        ).to eq({provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "gpt-4o-mini", tool_name: "weather", tool_call_id: "1234", result_class: "String"})
      end
    end

    context "with embedding.ruby_llm event" do
      it "excludes input text and result vectors" do
        expect(
          subscriber.format_payload("embedding.ruby_llm", {provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "text-embedding-3-small", response_model: "text-embedding-3-small", input_tokens: 5, embedding_dimensions: 1536, embedding_count: 1, model_info: :object, input: :value, result: :value})
        ).to eq({provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "text-embedding-3-small", response_model: "text-embedding-3-small", input_tokens: 5, embedding_dimensions: 1536, embedding_count: 1})
      end
    end

    context "with image.ruby_llm event" do
      it "excludes the prompt and result" do
        expect(
          subscriber.format_payload("image.ruby_llm", {provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "dall-e-3", size: "1024x1024", model_info: :object, prompt: :value, result: :value})
        ).to eq({provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "dall-e-3", size: "1024x1024"})
      end
    end

    context "with moderation.ruby_llm event" do
      it "excludes the input and result" do
        expect(
          subscriber.format_payload("moderation.ruby_llm", {provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "omni-moderation-latest", flagged: true, model_info: :object, input: :value, result: :value})
        ).to eq({provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "omni-moderation-latest", flagged: true})
      end
    end

    context "with transcription.ruby_llm event" do
      it "excludes the result" do
        expect(
          subscriber.format_payload("transcription.ruby_llm", {provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "whisper-1", language: "en", input_tokens: 5, output_tokens: 10, model_info: :object, result: :value})
        ).to eq({provider: "openai", provider_class: "RubyLLM::Providers::OpenAI", model: "whisper-1", language: "en", input_tokens: 5, output_tokens: 10})
      end
    end

    context "with models.refresh.ruby_llm event" do
      it "includes refresh metadata" do
        expect(
          subscriber.format_payload("models.refresh.ruby_llm", {remote_only: false, model_count: 100, exception_object: :object})
        ).to eq({remote_only: false, model_count: 100})
      end
    end

    context "with an exception in the payload" do
      it "includes the exception class and message but not the exception object" do
        expect(
          subscriber.format_payload("chat.ruby_llm", {provider: "openai", model: "gpt-4o-mini", exception: ["RubyLLM::Error", "rate limited"], exception_object: :object})
        ).to eq({provider: "openai", model: "gpt-4o-mini", exception: ["RubyLLM::Error", "rate limited"]})
      end
    end

    context "with other events" do
      it "allows only safe metadata keys through" do
        expect(
          subscriber.format_payload("other.ruby_llm", {provider: "openai", model: "gpt-4o-mini", input_messages: :value, unknown: :value})
        ).to eq({provider: "openai", model: "gpt-4o-mini"})
      end
    end
  end
end
