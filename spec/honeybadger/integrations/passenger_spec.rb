require 'spec_helper'

describe "Passenger integration" do
  before do
    Honeybadger::Dependency.reset!
  end

  context "when passenger is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Dependency.inject! }.not_to raise_error
    end
  end

  context "when passenger is installed" do
    let(:shim) { double('PhusionPassenger') }

    before do
      Object.const_set(:PhusionPassenger, shim)
    end
    after { Object.send(:remove_const, :PhusionPassenger) }

    it "installs passenger hooks" do
      shim.should_receive(:on_event).with(:starting_worker_process)
      shim.should_receive(:on_event).with(:stopping_worker_process)
      Honeybadger::Dependency.inject!
    end
  end
end

