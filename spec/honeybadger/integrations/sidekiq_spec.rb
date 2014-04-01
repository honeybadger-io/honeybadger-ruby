require 'spec_helper'

describe "Sidekiq Dependency" do
  before do
    Honeybadger::Dependency.reset!
  end

  context "when sidekiq is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Dependency.inject! }.not_to raise_error
    end
  end

  context "when sidekiq is installed" do
    let(:shim) do
      Class.new do
        def self.configure_server
        end
      end
    end

    let(:config) { double('config', :error_handlers => []) }
    let(:chain) { double('chain', :add => true) }

    before do
      Object.const_set(:Sidekiq, shim)
      ::Sidekiq.stub(:configure_server).and_yield(config)
      config.stub(:server_middleware).and_yield(chain)
    end

    after { Object.send(:remove_const, :Sidekiq) }

    context "when version is less than 3" do
      before do
        ::Sidekiq.const_set(:VERSION, '2.17.7')
      end

      it "adds the server middleware" do
        chain.should_receive(:add).with(Honeybadger::Integrations::Sidekiq::Middleware)
        Honeybadger::Dependency.inject!
      end

      it "doesn't add the error handler" do
        Honeybadger::Dependency.inject!
        expect(config.error_handlers).to be_empty
      end
    end

    context "when version is 3 or greater" do
      before do
        ::Sidekiq.const_set(:VERSION, '3.0.0')
      end

      it "adds the error handler" do
        Honeybadger::Dependency.inject!
        expect(config.error_handlers).not_to be_empty
      end
    end
  end
end
