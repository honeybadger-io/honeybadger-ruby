require 'honeybadger/backend/debug'
require 'honeybadger/config'

describe Honeybadger::Backend::Debug do
  let(:logger) { double('Logger', warn: true, debug: true) }
  let(:config) { Honeybadger::Config.new(logger: logger) }

  let(:instance) { described_class.new(config) }

  subject { instance }

  it { should respond_to :notify }

  describe "#notify" do
    let(:notice) { double('Notice', to_json: '{}') }

    subject { instance.notify(:notices, notice) }

    it { should be_a Honeybadger::Backend::Response }

    it "logs the notice" do
      expect(logger).to receive(:debug).with(/feature=notices/)
      instance.notify(:notices, notice)
    end
  end
end
