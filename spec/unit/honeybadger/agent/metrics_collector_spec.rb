require 'honeybadger/agent/metrics_collector'
require 'honeybadger/config'

describe Honeybadger::Agent::MetricsCollector do
  let(:config) { Honeybadger::Config.new }
  let(:instance) { described_class.new(config) }

  describe "#to_json" do
    subject { instance.to_json }

    it { should eq instance.as_json.to_json }
  end

  describe "#size" do
    subject { instance.size }
    it { should eq 0 }

    context "with metrics" do
      before do
        instance.timing(:foo, 20)
        instance.timing(:bar, 5)
        instance.increment(:foo, 10)
        instance.increment(:bar, 6)
      end

      it "counts the metrics" do
        should eq 4
      end
    end
  end
end
