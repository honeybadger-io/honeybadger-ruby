require 'honeybadger/plugins/karafka'
require 'honeybadger/config'

describe "Karafka Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:karafka].reset!
  end

  context "when Karafka is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:karafka].load!(config) }.not_to raise_error
    end
  end

  context "when Karafka is installed" do
    let(:shim) do
      Class.new do
        def self.monitor
        end
      end
    end
    let(:event) { double('event') }

    before do
      Object.const_set(:Karafka, shim)
    end
    after { Object.send(:remove_const, :Karafka) }

    it "includes integration module into Karafka" do
      expect(::Karafka).to receive_message_chain(:monitor, :subscribe).with('error.occurred').and_yield(event)
      expect(event).to receive(:[]).with(:error).and_return(RuntimeError.new)
      Honeybadger::Plugin.instances[:karafka].load!(config)
    end
  end
end
