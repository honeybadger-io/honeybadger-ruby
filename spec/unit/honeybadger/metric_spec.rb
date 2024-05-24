# encoding: utf-8

describe Honeybadger::Metric do
  describe ".register" do
    let(:name) { "capacity" }
    let(:attributes) { { foo: "bar" } }

    subject { described_class.register(name, attributes) }

    context "returns a new instance" do
      it { should be_a(Honeybadger::Metric) }
    end

    context "returns the same instance if called twice" do
      let(:instance) { described_class.register(name, attributes) }

      subject { described_class.register(name, attributes) }

      it { should eq(instance) }
    end
  end

  describe ".signature" do
    subject { described_class.signature(metric_type, name, attributes) }

    context "with metric_type, name, and attributes" do
      let(:metric_type) { "gauge" }
      let(:name) { "capacity" }
      let(:attributes) { { foo: "bar" } }

      it { should eq :"gauge-capacity-foo-bar" }
    end
  end

  describe "#signature" do
    subject { described_class.new(name, attributes).signature }

    context "with name, and attributes" do
      let(:name) { "capacity" }
      let(:attributes) { { foo: "bar" } }

      it { should eq :"metric-capacity-foo-bar" }
    end
  end
end