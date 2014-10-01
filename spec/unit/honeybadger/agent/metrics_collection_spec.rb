require 'honeybadger/agent/metrics_collection'

describe Honeybadger::Agent::MetricsCollection do
  describe "#sum" do
    it "returns the sum of values in the collection" do
      subject.replace([1,2,3])
      expect(subject.sum).to eq 6
    end
  end

  describe "#mean" do
    it "returns the mean of the collection" do
      subject.replace([1,2,3])
      expect(subject.mean).to eq 2
    end
  end

  describe "#median" do
    it "returns the median of the collection" do
      subject.replace([1,2,3,4,5])
      expect(subject.median).to eq 3
    end
  end

  describe "#percentile" do
    context "when collection has more than one value" do
      it "returns the value of the upper percentile of values in the collection" do
        subject.replace([1,2,3,4,5])
        expect(subject.percentile(75)).to eq 5
      end
    end

    context "when collection has one value or less" do
      it "returns the first value" do
        expect(subject.percentile(50)).to be_nil
        subject.replace([1])
        expect(subject.percentile(50)).to eq 1
      end
    end
  end

  describe "#mean_squared" do
    it "returns the mean squared" do
      subject.replace([1,2,3,4,5])
      expect(subject.mean_squared).to eq 10
    end
  end

  describe "#standard_dev" do
    it "returns the standard deviation" do
      subject.replace([1,2,3,4,5])
      expect(subject.standard_dev.round(2)).to eq 1.58
    end
  end

  describe "#respond_to_missing?" do
    it { should_not respond_to :obviously_missing }
  end

  describe "#method_missing" do
    specify { expect { subject.obviously_missing }.to raise_error(NoMethodError) }
  end

  describe "#percentile_*" do
    [90, 75, 50].each do |percentile|
      method = :"percentile_#{percentile}"

      it { should respond_to method }

      it "returns the value returned by #percentile(i)" do
        expect(subject.send(method)).to eq(subject.percentile(percentile))
      end
    end
  end
end
