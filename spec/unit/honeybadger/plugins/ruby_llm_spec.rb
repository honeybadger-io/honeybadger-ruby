require "honeybadger/plugins/ruby_llm"
require "honeybadger/config"

describe "RubyLLM Plugin" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:ruby_llm].reset!
  end

  context "when ruby_llm is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:ruby_llm].load!(config) }.not_to raise_error
    end
  end

  context "when ruby_llm is installed" do
    let(:provider_class) do
      Class.new do
        def slug
          "test"
        end

        def complete(messages, tools:, temperature:, model:, **kwargs, &block)
          "response"
        end

        def embed(text, model:, dimensions:)
          "embedding"
        end

        def paint(prompt, model:, size:)
          "image"
        end

        def transcribe(audio_file, model:, language:, **options)
          "transcription"
        end
      end
    end

    let(:chat_class) do
      Class.new do
        private

        def execute_tool(tool_call)
          "result"
        end
      end
    end

    let(:ruby_llm_shim) do
      mod = Module.new
      mod.const_set(:Provider, provider_class)
      mod.const_set(:Chat, chat_class)
      mod
    end

    before do
      Object.const_set(:RubyLLM, ruby_llm_shim)
    end

    after do
      # Remove prepended modules by restoring original classes
      Object.send(:remove_const, :RubyLLM)
    end

    context "when insights are enabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": true) }

      it "prepends instrumentation on Provider" do
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)
        expect(provider_class.ancestors).to include(Honeybadger::Plugins::RubyLLM::ProviderInstrumentation)
      end

      it "prepends instrumentation on Chat" do
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)
        expect(chat_class.ancestors).to include(Honeybadger::Plugins::RubyLLM::ChatInstrumentation)
      end
    end

    context "when insights are disabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": false) }

      it "does not prepend instrumentation" do
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)
        expect(provider_class.ancestors).not_to include(Honeybadger::Plugins::RubyLLM::ProviderInstrumentation)
      end
    end

    context "when ruby_llm insights are disabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "ruby_llm.insights.enabled": false) }

      it "does not prepend instrumentation" do
        Honeybadger::Plugin.instances[:ruby_llm].load!(config)
        expect(provider_class.ancestors).not_to include(Honeybadger::Plugins::RubyLLM::ProviderInstrumentation)
      end
    end
  end
end

describe Honeybadger::Plugins::RubyLLM::ProviderInstrumentation do
  let(:model_info) do
    double("ModelInfo", id: "gpt-4o")
  end

  let(:tokens) do
    double("Tokens", input: 100, output: 50, cached: 10, thinking: 5)
  end

  let(:response) do
    double("Message", tokens: tokens, tool_calls: [double("ToolCall")])
  end

  let(:provider_class) do
    Class.new do
      def slug
        "openai"
      end

      def complete(messages, tools:, temperature:, model:, **kwargs, &block)
        @response
      end

      def embed(text, model:, dimensions:)
        @embed_response
      end

      def paint(prompt, model:, size:)
        @paint_response
      end

      def transcribe(audio_file, model:, language:, **options)
        @transcribe_response
      end
    end.prepend(described_class)
  end

  let(:provider) { provider_class.new }

  before do
    allow(Honeybadger).to receive(:event)
  end

  describe "#complete" do
    before do
      provider.instance_variable_set(:@response, response)
    end

    it "calls Honeybadger.event with complete payload" do
      provider.complete(["msg1", "msg2"], tools: [:tool1], temperature: 0.7, model: model_info)

      expect(Honeybadger).to have_received(:event).with(hash_including(
        event_type: "complete.ruby_llm",
        provider: "openai",
        model: "gpt-4o",
        stream: false,
        temperature: 0.7,
        tool_count: 1,
        message_count: 2,
        input_tokens: 100,
        output_tokens: 50,
        cached_tokens: 10,
        thinking_tokens: 5,
        tool_call_count: 1
      ))
    end

    it "includes duration" do
      provider.complete(["msg"], tools: [], temperature: 0.5, model: model_info)

      expect(Honeybadger).to have_received(:event).with(hash_including(
        duration: a_kind_of(Numeric)
      ))
    end

    it "returns the response" do
      result = provider.complete(["msg"], tools: [], temperature: 0.5, model: model_info)
      expect(result).to eq(response)
    end

    it "detects streaming when a block is given" do
      provider.complete(["msg"], tools: [], temperature: 0.5, model: model_info) { |chunk| }

      expect(Honeybadger).to have_received(:event).with(hash_including(stream: true))
    end
  end

  describe "#embed" do
    let(:embed_response) { double("Embedding", input_tokens: 42) }

    before do
      provider.instance_variable_set(:@embed_response, embed_response)
    end

    it "calls Honeybadger.event with embed payload" do
      provider.embed("hello", model: "text-embedding-3-small", dimensions: 1536)

      expect(Honeybadger).to have_received(:event).with(hash_including(
        event_type: "embed.ruby_llm",
        provider: "openai",
        model: "text-embedding-3-small",
        input_tokens: 42
      ))
    end

    it "returns the response" do
      result = provider.embed("hello", model: "text-embedding-3-small", dimensions: 1536)
      expect(result).to eq(embed_response)
    end
  end

  describe "#paint" do
    let(:paint_response) { double("Image") }

    before do
      provider.instance_variable_set(:@paint_response, paint_response)
    end

    it "calls Honeybadger.event with paint payload" do
      provider.paint("a cat", model: "dall-e-3", size: "1024x1024")

      expect(Honeybadger).to have_received(:event).with(hash_including(
        event_type: "paint.ruby_llm",
        provider: "openai",
        model: "dall-e-3",
        size: "1024x1024"
      ))
    end

    it "returns the response" do
      result = provider.paint("a cat", model: "dall-e-3", size: "1024x1024")
      expect(result).to eq(paint_response)
    end
  end

  describe "#transcribe" do
    let(:transcribe_response) { double("Transcription") }

    before do
      provider.instance_variable_set(:@transcribe_response, transcribe_response)
    end

    it "calls Honeybadger.event with transcribe payload" do
      provider.transcribe("audio.mp3", model: "whisper-1", language: "en")

      expect(Honeybadger).to have_received(:event).with(hash_including(
        event_type: "transcribe.ruby_llm",
        provider: "openai",
        model: "whisper-1",
        language: "en"
      ))
    end

    it "returns the response" do
      result = provider.transcribe("audio.mp3", model: "whisper-1", language: "en")
      expect(result).to eq(transcribe_response)
    end
  end
end

describe Honeybadger::Plugins::RubyLLM::ChatInstrumentation do
  let(:tool_call) { double("ToolCall", name: "search") }

  let(:chat_class) do
    Class.new do
      private

      def execute_tool(tool_call)
        "tool result"
      end
    end.prepend(described_class)
  end

  let(:chat) { chat_class.new }

  before do
    allow(Honeybadger).to receive(:event)
  end

  it "calls Honeybadger.event with tool_call payload" do
    chat.send(:execute_tool, tool_call)

    expect(Honeybadger).to have_received(:event).with(hash_including(
      event_type: "tool_call.ruby_llm",
      tool_name: "search",
      duration: a_kind_of(Numeric)
    ))
  end

  it "returns the result" do
    result = chat.send(:execute_tool, tool_call)
    expect(result).to eq("tool result")
  end
end
