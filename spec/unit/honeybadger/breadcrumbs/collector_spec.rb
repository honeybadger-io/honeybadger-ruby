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

    it '#each' do
      expect(buffer).to receive(:each)
      subject.each
    end
  end


  describe "#add!" do
    it "delegates to " do
      crumb = double("Crumb")
      expect(buffer).to receive(:add!).with(crumb)
      subject.add!(crumb)
    end

    context "breadcrumbs disabled in config" do
      let(:config) { Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER, :'breadcrumbs.enabled' => false) }

      it 'does not call buffer' do
        crumb = double("Crumb")
        expect(buffer).to_not receive(:add!)
        subject.add!(crumb)
      end
    end
  end

  describe "#<<" do
    it 'delegates to add!' do
      expect(subject.method(:<<)).to eq(subject.method(:add!))
    end
  end

  describe "to_h" do
    before do
      allow(subject).to receive(:trail).and_return([])
    end

    it 'contains trail summary' do
      trail = [buffer]
      expect(buffer).to receive(:to_h).and_return({test: "buffer"})
      expect(subject).to receive(:trail).and_return(trail)
      expect(subject.to_h).to match(hash_including({ trail: [{test: "buffer"}] }))
    end

    it 'works with empty trail' do
      expect(subject.to_h).to match(hash_including({ trail: [] }))
    end

    it 'contains enabled flag' do
      expect(subject.to_h).to match(hash_including({ enabled: true }))
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
