require 'honeybadger/breadcrumbs/collector'

describe Breadcrumbs::Collector do
  let(:buffer) { double("Buffer") }
  let(:config) { Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER) }
  subject { described_class.new(config, buffer) }

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
      expect(buffer).to receive(:to_a).and_return(all_crumbs)
      expect(subject.crumbs).to eq(all_crumbs)
    end

    it '#each' do
      expect(buffer).to receive(:each)
      subject.each
    end
  end
end
