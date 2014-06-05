require 'spec_helper'
require 'honeybadger/monitor'

describe Honeybadger::Monitor::Trace do
  describe "::instrument" do
    it "creates a new trace" do
      Honeybadger::Monitor::Trace.should_receive(:new).and_call_original
      described_class.instrument('testing', {}){}
    end
  end
end
