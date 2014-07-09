require 'spec_helper'

describe "Unicorn integration" do
  before do
    Honeybadger::Dependency.reset!
  end

  context "when unicorn is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Dependency.inject! }.not_to raise_error
    end
  end

  context "when unicorn is installed" do
    let(:shim) {
      Class.new {
        def init_worker_process(worker)
          'foo'
        end
      }
    }

    before do
      Object.const_set(:Unicorn, Module.new)
      Unicorn.const_set(:HttpServer, shim)
    end
    after { Object.send(:remove_const, :Unicorn) }

    it "logs installation" do
      Honeybadger.should_receive(:write_verbose_log).with(/Unicorn/)
      Honeybadger::Dependency.inject!
    end

    it "installs unicorn hooks" do
      Honeybadger::Dependency.inject!
      Honeybadger::Monitor.worker.should_receive(:fork)
      expect(shim.new.init_worker_process(double('worker'))).to eq 'foo'
    end
  end
end
