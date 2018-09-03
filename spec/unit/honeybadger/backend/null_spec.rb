require 'honeybadger/backend/null'
require 'honeybadger/config'

describe Honeybadger::Backend::Null do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER) }
  let(:logger) { config.logger }

  let(:instance) { described_class.new(config) }

  subject { instance }

  it { should respond_to :notify }

  describe "#notify" do
    subject { instance.notify(:notices, double('Notice')) }
    
    it { should be_a Honeybadger::Backend::Response }
  end

  describe "#check_in" do
    subject { instance.check_in(10) }

    it { should be_a Honeybadger::Backend::Response }
  end
end

