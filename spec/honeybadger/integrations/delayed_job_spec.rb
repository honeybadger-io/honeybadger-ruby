require 'spec_helper'

describe "DelayedJob Dependency" do
  before do
    Honeybadger::Dependency.reset!
  end

  context "when delayed_job is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Dependency.inject! }.not_to raise_error
    end
  end

  context "when delayed_job is installed" do
    let(:plugins_array) { [] }
    let(:plugin_class) do
      Class.new do
        def self.callbacks(&block)
        end
      end
    end

    before do
      Object.const_set(:Delayed, Module.new)
      ::Delayed.const_set(:Plugins, Module.new)
      ::Delayed::Plugins.const_set(:Plugin, plugin_class)
      ::Delayed.const_set(:Worker, double(:plugins => plugins_array))
    end

    after { Object.send(:remove_const, :Delayed) }

    it "adds the plugin to DelayedJob" do
      Honeybadger::Dependency.inject!
      expect(plugins_array).to include(Honeybadger::Integrations::DelayedJob::Plugin)
    end

    context "and delayed_job_honeybadger is installed" do
      before do
        ::Delayed::Plugins.const_set(:Honeybadger, Class.new(plugin_class))
      end

      it "warns the user of the conflict" do
        Honeybadger.should_receive(:write_verbose_log).with(/Support for Delayed Job has been moved/, :warn).once
        Honeybadger::Dependency.inject!
      end
    end
  end
end
