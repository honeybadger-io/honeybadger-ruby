require "honeybadger/plugins/thor"
require "honeybadger/config"

describe "Thor Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:thor].reset!
  end

  context "when thor is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:thor].load!(config) }.not_to raise_error
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
      stub_const("Thor", shim)
    end

    it "includes integration module into Thor" do
      expect(shim).to receive(:send).with(:include, Honeybadger::Plugins::Thor)
      Honeybadger::Plugin.instances[:thor].load!(config)
    end
  end
end
