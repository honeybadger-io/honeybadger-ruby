require 'spec_helper'

describe "Thor Dependency" do
  before do
    Honeybadger::Dependency.reset!
  end

  context "when thor is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Dependency.inject! }.not_to raise_error
    end
  end

  context "when thor is installed" do
    let(:shim) do
      Class.new do
        def self.no_commands
        end
      end
    end

    before do
      Object.const_set(:Thor, shim)
    end
    after { Object.send(:remove_const, :Thor) }

    it "includes integration module into Thor" do
      shim.should_receive(:send).with(:include, Honeybadger::Integrations::Thor)
      Honeybadger::Dependency.inject!
    end
  end
end
