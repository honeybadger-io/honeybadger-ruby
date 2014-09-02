require 'honeybadger/backend/test'
require 'honeybadger/config'

describe Honeybadger::Backend::Test do
  let(:logger) { double('Logger', warn: true, debug: true) }
  let(:config) { Honeybadger::Config.new(logger: logger) }


  let(:instance) { described_class.new(config) }

  subject { instance }

  it { should respond_to :notifications }

  it "warns when it's initialized" do
    expect(logger).to receive(:warn).with(/development backend/)
    described_class.new(config)
  end

  describe "#notify" do
    let(:notice) { double('Notice') }

    subject { instance.notify(:notices, double('Notice')) }

    it "saves notifications for review" do
      expect { instance.notify(:notices, notice) }.to change { instance.notifications[:notices] }.from([]).to([notice])
    end

    it { should be_a Honeybadger::Backend::Response }
  end
end
