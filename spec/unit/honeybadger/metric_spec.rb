describe Honeybadger::Metric do
  let(:registry) { Honeybadger::Registry.new }

  describe ".register" do
    let(:name) { "capacity" }
    let(:attributes) { {foo: "bar"} }

    subject { described_class.register(registry, name, attributes) }

    context "returns a new instance" do
      it { should be_a(Honeybadger::Metric) }
    end

    context "returns the same instance if called twice" do
      let(:instance) { described_class.register(registry, name, attributes) }

      subject { described_class.register(registry, name, attributes) }

      it { should eq(instance) }
    end
  end

  describe ".signature" do
    subject { described_class.signature(metric_type, name, attributes) }

    context "with metric_type, name, and attributes" do
      let(:metric_type) { "gauge" }
      let(:name) { "capacity" }
      let(:attributes) { {foo: "bar"} }

      it { should eq Digest::SHA1.hexdigest("gauge-capacity-foo-bar").to_sym }
    end
  end

  describe "#signature" do
    subject { described_class.new(name, attributes).signature }

    context "with name, and attributes" do
      let(:name) { "capacity" }
      let(:attributes) { {foo: "bar"} }

      it { should eq Digest::SHA1.hexdigest("metric-capacity-foo-bar").to_sym }
    end
  end
end
