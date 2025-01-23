describe Honeybadger::Histogram do
  describe "#payloads" do
    let(:metric) { described_class.new(name, attributes) }
    let(:name) { "perform" }
    let(:attributes) { {foo: "bar"} }

    subject { metric.payloads }

    before { metric.record(1) }

    it do
      should eq [
        {
          total: 1,
          avg: 1.0,
          latest: 1,
          max: 1,
          min: 1,
          bins: [[0.005, 0], [0.01, 0], [0.025, 0], [0.05, 0], [0.1, 0], [0.25, 0], [0.5, 0], [1.0, 1], [2.5, 0], [5.0, 0], [10.0, 0], [1.0e+20, 0]]
        }
      ]
    end
  end
end
