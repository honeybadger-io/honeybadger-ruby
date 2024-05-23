# encoding: utf-8

describe Honeybadger::Gauge do
  describe "#payloads" do
    let(:metric) { described_class.new(name, attributes) }
    let(:name) { "perform" }
    let(:attributes) { { foo: "bar" } }

    subject { metric.payloads }

    before { metric.record(1) }

    it { should eq [{ avg: 1.0, latest: 1, max: 1, min: 1 }] }
  end
end
