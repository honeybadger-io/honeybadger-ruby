require "honeybadger/plugins/karafka"
require "honeybadger/karafka"
require "honeybadger/config"

describe "Karafka Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": false) }

  before do
    Honeybadger::Plugin.instances[:karafka].reset!
  end

  context "when Karafka is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:karafka].load!(config) }.not_to raise_error
    end
  end

  context "when Karafka is installed" do
    let(:shim) do
      Class.new do
        def self.monitor
        end
      end
    end
    let(:monitor) { double("monitor") }
    let(:event) { double("event") }
    let(:errors_listener) { double("errors listener") }

    before do
      Object.const_set(:Karafka, shim)
      allow(::Karafka).to receive(:monitor).and_return(monitor)
      allow(::Honeybadger::Karafka::ErrorsListener).to receive(:new).and_return(errors_listener)
    end
    after { Object.send(:remove_const, :Karafka) }

    it "includes integration module into Karafka" do
      expect(monitor).to receive(:subscribe).with(errors_listener)
      Honeybadger::Plugin.instances[:karafka].load!(config)
    end

    context "when Insights instrumentation is enabled" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true) }
      let(:insights_listener) { double("insights listener") }

      before do
        allow(::Honeybadger::Karafka::InsightsListener).to receive(:new).and_return(insights_listener)
      end

      it "includes integration module into Karafka" do
        expect(monitor).to receive(:subscribe).with(errors_listener)
        expect(monitor).to receive(:subscribe).with(insights_listener)
        Honeybadger::Plugin.instances[:karafka].load!(config)
      end
    end
  end
end
