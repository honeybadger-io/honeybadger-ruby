require 'honeybadger/backend/null'
require 'honeybadger/config'

describe Honeybadger::Backend::Null do
  let(:logger) { double('Logger', warn: true, debug: true) }
  let(:config) { Honeybadger::Config.new(logger: logger) }

  let(:instance) { described_class.new(config) }

  subject { instance }

  it { should respond_to :notify }

  it "warns when it's initialized" do
    expect(logger).to receive(:warn).with(/development backend/)
    described_class.new(config)
  end

  describe "#notify" do
    subject { instance.notify(:notices, double('Notice')) }
    it { should be_a Honeybadger::Backend::Response }
  end
end

