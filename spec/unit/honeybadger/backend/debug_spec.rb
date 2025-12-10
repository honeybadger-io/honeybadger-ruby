require "honeybadger/backend/debug"
require "honeybadger/config"

RSpec.describe Honeybadger::Backend::Debug do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }
  let(:logger) { config.logger }

  let(:instance) { described_class.new(config) }

  subject { instance }

  before do
    allow(logger).to receive(:warn)
    allow(logger).to receive(:unknown)
  end

  it { should respond_to :notify }

  describe "#notify" do
    let(:notice) { double("Notice", to_json: "{}") }

    subject { instance.notify(:notices, notice) }

    it { should be_a Honeybadger::Backend::Response }

    it "logs the notice" do
      expect(logger).to receive(:unknown).with(/feature=notices/)
      instance.notify(:notices, notice)
    end
  end

  describe "#check_in" do
    it "logs the check_in" do
      expect(logger).to receive(:unknown).with("checking in debug backend with id=10")

      instance.check_in(10)
    end
  end

  describe "#event" do
    it "logs the event" do
      expect(logger).to receive(:unknown) do |msg|
        expect(msg).to match(/"some_data":"is here"/)
        expect(msg).to match(/"event_type":"test_event"/)
        expect(msg).to match(/"ts":"test_timestamp"/)
      end

      instance.event({event_type: "test_event", ts: "test_timestamp", some_data: "is here"})
    end
  end
end
