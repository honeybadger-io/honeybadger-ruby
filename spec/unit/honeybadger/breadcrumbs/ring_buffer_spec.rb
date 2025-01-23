require "honeybadger/breadcrumbs/ring_buffer"

describe Honeybadger::Breadcrumbs::RingBuffer do
  describe "#add" do
    it "adds items" do
      subject.add!(:a)
      expect(subject.buffer).to eq([:a])
    end

    it "shifts when size limit is hit" do
      buffer = described_class.new(2)
      buffer.add!(:a)
      buffer.add!(:b)
      buffer.add!(:c)

      expect(buffer.buffer).to eq([:b, :c])
    end
  end

  describe "#clear" do
    it "clears data" do
      subject.add!(:a)
      subject.clear!
      expect(subject.buffer).to be_empty
    end
  end

  describe "#each" do
    it "enumerates over buffer" do
      subject.add!(:a)
      subject.add!(:b)
      expect(subject.reduce([]) { |m, v| m << v }).to eq([:a, :b])
    end
  end

  describe "#drop" do
    it "removes the last inserted item" do
      subject.add!(:a)
      subject.add!(:b)
      subject.drop
      expect(subject.buffer).to eq([:a])
    end
  end

  describe "#previous" do
    it "returns the last inserted item" do
      subject.add!(:a)
      subject.add!(:b)
      expect(subject.previous).to eq(:b)
    end
  end
end
