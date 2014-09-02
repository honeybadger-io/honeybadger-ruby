require 'honeybadger/backend/base'
require 'honeybadger/config'

describe Honeybadger::Backend::Base do
  let(:config) { Honeybadger::Config.new }

  subject { described_class.new(config) }

  it { should respond_to :notify }

  describe "#notify" do
    it "raises NotImplementedError" do
      expect { subject.notify(:notices, double('Notice')) }.to raise_error NotImplementedError
    end
  end
end
