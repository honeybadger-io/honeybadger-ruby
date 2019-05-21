require 'honeybadger/breadcrumbs/breadcrumb'
require 'honeybadger/breadcrumbs/collector'

describe Honeybadger::Breadcrumbs::Collector do
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

    it '#each' do
      expect(buffer).to receive(:each)
      subject.each
    end
  end

  describe "to_h" do
    it 'returns collection summary' do
      trail = [:a]
      expect(subject).to receive(:trail).and_return(trail)
      expect(subject.to_h).to eq({ trail: trail })
    end
  end

  describe "#trail" do
    let(:active_breadcrumb) { instance_double(Honeybadger::Breadcrumbs::Breadcrumb, active?: true) }
    let(:buffer) {[
      instance_double(Honeybadger::Breadcrumbs::Breadcrumb, active?: false),
      active_breadcrumb,
    ]}

    it "only returns active breadcrumbs" do
      expect(subject.trail.length).to eq(1)
      expect(subject.trail.first).to eq(active_breadcrumb)
    end
  end
end
