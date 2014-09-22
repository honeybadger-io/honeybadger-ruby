require 'honeybadger/plugins/unicorn'
require 'honeybadger/config'

describe "Unicorn integration" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:unicorn].reset!
    allow(config.logger).to receive(:debug)
  end

  context "when unicorn is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:unicorn].load!(config) }.not_to raise_error
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
      expect(config.logger).to receive(:debug).with(/Unicorn/i)
      Honeybadger::Plugin.instances[:unicorn].load!(config)
    end

    it "installs unicorn hooks" do
      Honeybadger::Plugin.instances[:unicorn].load!(config)
      expect(Honeybadger::Agent).to receive(:fork)
      expect(shim.new.init_worker_process(double('worker'))).to eq 'foo'
    end
  end
end
