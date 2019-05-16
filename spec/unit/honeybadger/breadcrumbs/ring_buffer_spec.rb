require 'honeybadger/breadcrumbs/ring_buffer'

describe Breadcrumbs::RingBuffer do
  describe "#add" do
    it 'adds items' do
      subject.add!(:a)
      expect(subject.buffer).to eq([:a])
    end

    it 'shifts when size limit is hit' do
      buffer = described_class.new(2)
      buffer.add!(:a)
      buffer.add!(:b)
      buffer.add!(:c)

      expect(buffer.buffer).to eq([:b, :c])
    end
  end

  describe "#clear" do
    it 'clears data' do
      subject.add!(:a)
      subject.clear!
      expect(subject.buffer).to be_empty
    end
  end
end
