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

  context "when Active Agent is installed" do
    let(:active_agent_shim) do
      Module.new
    end

    let(:notifications_shim) do
      Module.new do
        def self.subscribe(*args)
        end
      end
    end

    let(:active_support_shim) do
      Module.new
    end

    before do
      Object.const_set(:ActiveAgent, active_agent_shim)
      unless defined?(::ActiveSupport)
        Object.const_set(:ActiveSupport, active_support_shim)
        active_support_shim.const_set(:Notifications, notifications_shim)
      end
    end

    after do
      Object.send(:remove_const, :ActiveAgent)
      if defined?(::ActiveSupport) && active_support_shim == ::ActiveSupport
        Object.send(:remove_const, :ActiveSupport)
      end
    end

    context "when insights are enabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "active_agent.insights.enabled": true) }
      let(:subscriber) { instance_double(Honeybadger::ActiveAgentSubscriber) }

      before do
        allow(Honeybadger::ActiveAgentSubscriber).to receive(:new).and_return(subscriber)
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "subscribes to prompt.active_agent notifications" do
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
end
