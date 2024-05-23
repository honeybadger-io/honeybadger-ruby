# encoding: utf-8

describe Honeybadger::Counter do
  describe "#payloads" do
    let(:metric) { described_class.new(name, attributes) }
    let(:name) { "perform" }
    let(:attributes) { { foo: "bar" } }

    subject { metric.payloads }

    before { metric.count }

    it { should eq [{ counter: 1 }] }
  end
end
