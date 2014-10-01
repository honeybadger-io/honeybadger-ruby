require 'honeybadger/agent/metrics_collector'
require 'honeybadger/config'

describe Honeybadger::Agent::MetricsCollector do
  let(:config) { Honeybadger::Config.new }
  let(:instance) { described_class.new(config) }

  describe "#to_json" do
    subject { instance.to_json }

    it { should eq instance.as_json.to_json }
  end
end
