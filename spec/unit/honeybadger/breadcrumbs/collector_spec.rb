require 'honeybadger/breadcrumbs/collector'

describe Breadcrumbs::Collector do
  let(:buffer) { double("Buffer") }
  subject { described_class.new(buffer) }

  context 'buffer delegation' do
    it '#clear!' do
      expect(buffer).to receive(:clear!)
      subject.clear!
    end

    it '#add!' do
      crumb = double("Crumb")
      expect(buffer).to receive(:add!).with(crumb)
      subject.add!(crumb)
    end

    it '#crumbs' do
      all_crumbs = [:a, :b]
      expect(buffer).to receive(:buffer).and_return(all_crumbs)
      expect(subject.crumbs).to eq(all_crumbs)
    end

    it '#each' do
      expect(buffer).to receive(:each)
      subject.each
    end
  end
end
