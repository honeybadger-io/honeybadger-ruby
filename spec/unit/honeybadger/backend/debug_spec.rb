require 'honeybadger/backend/debug'
require 'honeybadger/config'

describe Honeybadger::Backend::Debug do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }
  let(:logger) { config.logger }

  let(:instance) { described_class.new(config) }

  subject { instance }

  before do
    allow(logger).to receive(:warn)
    allow(logger).to receive(:info)
  end

  it { should respond_to :notify }

  describe "#notify" do
    let(:notice) { double('Notice', to_json: '{}') }

    subject { instance.notify(:notices, notice) }

    it { should be_a Honeybadger::Backend::Response }

    it "logs the notice" do
      expect(logger).to receive(:info).with(/feature=notices/)
      instance.notify(:notices, notice)
    end
  end
end
