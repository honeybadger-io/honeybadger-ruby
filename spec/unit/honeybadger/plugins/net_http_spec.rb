require 'honeybadger/plugins/net_http'
require 'honeybadger/config'

begin
  require 'active_support/notifications'
rescue LoadError
  nil
end

describe "Net::HTTP Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:net_http].reset!
  end

  if defined?(ActiveSupport::Notifications)
    context "when active support notifications are installed" do
      it "installs instrumentation" do
        expect(Net::HTTP).to receive(:include).with(Honeybadger::Plugins::NetHttp::Instrumentation)
        Honeybadger::Plugin.instances[:net_http].load!(config)
      end

      context "when traces are disabled by configuration" do
        before do
          config[:'traces.enabled'] = false
        end

        it "does not install instrumentation" do
          expect(Net::HTTP).not_to receive(:include).with(Honeybadger::Plugins::NetHttp::Instrumentation)
          Honeybadger::Plugin.instances[:net_http].load!(config)
        end
      end
    end
  else
    context "when active support notifications are not installed" do
      it "does not install instrumentation" do
        expect(Net::HTTP).not_to receive(:include).with(Honeybadger::Plugins::NetHttp::Instrumentation)
        Honeybadger::Plugin.instances[:net_http].load!(config)
      end
    end
  end
end
