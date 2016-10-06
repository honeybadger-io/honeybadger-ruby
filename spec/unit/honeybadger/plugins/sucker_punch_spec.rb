require 'honeybadger/plugins/sucker_punch'

describe "SuckerPunch Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:sucker_punch].reset!
  end

  context "when sucker_punch is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:sucker_punch].load!(config) }.not_to raise_error
    end
  end

  context "when sucker_punch is installed" do
    let(:shim) do
      Class.new do
        def self.exception_handler=(handler)
          @exception_handler = handler
        end
      end
    end

    it "configures sucker_punch" do
      Object.const_set(:SuckerPunch, shim)
      expect(::SuckerPunch).to receive(:exception_handler=)
      Honeybadger::Plugin.instances[:sucker_punch].load!(config)
    end
  end
end
