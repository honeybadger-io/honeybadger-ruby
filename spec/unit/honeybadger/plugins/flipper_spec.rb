require "honeybadger/plugins/flipper"
require "honeybadger/config"

describe "Flipper Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:flipper].reset!
  end

  context "when flipper is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:flipper].load!(config) }.not_to raise_error
    end
  end

  context "when flipper is installed" do
    let(:flipper_shim) do
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
      Object.const_set(:Flipper, flipper_shim)
      unless defined?(::ActiveSupport::Notifications)
        Object.const_set(:ActiveSupport, active_support_shim)
        active_support_shim.const_set(:Notifications, notifications_shim)
      end
    end

    after do
      Object.send(:remove_const, :Flipper)
      if defined?(::ActiveSupport) && active_support_shim == ::ActiveSupport
        Object.send(:remove_const, :ActiveSupport)
      end
    end

    context "when insights are enabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "flipper.insights.enabled": true) }
      let(:subscriber) { instance_double(Honeybadger::FlipperSubscriber) }

      before do
        allow(Honeybadger::FlipperSubscriber).to receive(:new).and_return(subscriber)
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "subscribes to feature_operation.flipper notifications" do
        expect(ActiveSupport::Notifications).to receive(:subscribe).with(
          "feature_operation.flipper",
          subscriber
        )
        Honeybadger::Plugin.instances[:flipper].load!(config)
      end
    end

    context "when insights are disabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": false) }

      before do
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "does not subscribe to notifications" do
        expect(ActiveSupport::Notifications).not_to receive(:subscribe)
        Honeybadger::Plugin.instances[:flipper].load!(config)
      end
    end

    context "when flipper insights are disabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "flipper.insights.enabled": false) }

      before do
        allow(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it "does not subscribe to notifications" do
        expect(ActiveSupport::Notifications).not_to receive(:subscribe)
        Honeybadger::Plugin.instances[:flipper].load!(config)
      end
    end
  end
end

describe Honeybadger::FlipperSubscriber do
  let(:subscriber) { described_class.new }

  describe "#format_payload" do
    it "extracts feature_name, operation, and result" do
      payload = {
        feature_name: "new_feature",
        operation: "enabled?",
        result: true,
        extra_data: "ignored"
      }

      formatted = subscriber.format_payload(payload)

      expect(formatted).to eq({
        feature_name: "new_feature",
        operation: "enabled?",
        result: true
      })
    end
  end
end
