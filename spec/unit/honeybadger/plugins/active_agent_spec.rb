require "honeybadger/plugins/active_agent"
require "honeybadger/config"

describe "Active Agent Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:active_agent].reset!
  end

  context "when Active Agent is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:active_agent].load!(config) }.not_to raise_error
    end
  end

  context "when Active Agent is installed", if: defined?(::ActiveSupport::Notifications) do
    let(:active_agent_shim) do
      Module.new
    end

    before do
      Object.const_set(:ActiveAgent, active_agent_shim)
    end

    after { Object.send(:remove_const, :ActiveAgent) }

    context "when insights are enabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "active_agent.insights.enabled": true) }
      let(:subscriber) { instance_double(Honeybadger::ActiveAgentSubscriber) }

      before do
        allow(Honeybadger::ActiveAgentSubscriber).to receive(:new).and_return(subscriber)
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "subscribes to Active Agent notifications" do
        expect(ActiveSupport::Notifications).to receive(:subscribe).with(
          match("prompt.active_agent"),
          subscriber
        )
        Honeybadger::Plugin.instances[:active_agent].load!(config)
      end
    end

    context "when insights are disabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": false) }

      before do
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "does not subscribe to notifications" do
        expect(ActiveSupport::Notifications).not_to receive(:subscribe)
        Honeybadger::Plugin.instances[:active_agent].load!(config)
      end
    end

    context "when Active Agent insights are disabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "active_agent.insights.enabled": false) }

      before do
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "does not subscribe to notifications" do
        expect(ActiveSupport::Notifications).not_to receive(:subscribe)
        Honeybadger::Plugin.instances[:active_agent].load!(config)
      end
    end
  end
end

describe Honeybadger::ActiveAgentSubscriber do
  let(:subscriber) { described_class.new }

  it "is a NotificationSubscriber" do
    expect(subscriber).to be_a(Honeybadger::NotificationSubscriber)
  end

  describe "#format_payload" do
    context "with prompt.active_agent event" do
      it "excludes messages and parameters keys" do
        expect(
          described_class.new.format_payload("prompt.active_agent", { provider: "OpenAI", provider_module: "OpenAI::Responses", model: "gpt-4o-mini", trace_id: "1234", messages: :value, parameters: :value })
        ).to eq({ provider: "OpenAI", provider_module: "OpenAI::Responses", model: "gpt-4o-mini", trace_id: "1234" })
      end
    end
  end

  context "with embed.active_agent event" do
    it "excludes parameters key" do
      expect(
        described_class.new.format_payload("embed.active_agent", { provider: "OpenAI", provider_module: "OpenAI::Responses", model: "gpt-4o-mini", trace_id: "1234", parameters: :value })
      ).to eq({ provider: "OpenAI", provider_module: "OpenAI::Responses", model: "gpt-4o-mini", trace_id: "1234" })
    end
  end

  context "with other events" do
    it "includes all keys" do
      expect(
        described_class.new.format_payload("other.active_agent", { provider: "OpenAI", provider_module: "OpenAI::Responses", model: "gpt-4o-mini", trace_id: "1234", unknown: :value })
      ).to eq({ provider: "OpenAI", provider_module: "OpenAI::Responses", model: "gpt-4o-mini", trace_id: "1234", unknown: :value })
    end
  end
end
