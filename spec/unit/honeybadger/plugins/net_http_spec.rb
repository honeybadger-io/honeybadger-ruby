require 'honeybadger/plugins/net_http'
require 'honeybadger/config'

describe "Net::HTTP integration" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, :'insights.metrics' => true) }

  before do
    Honeybadger::Plugin.instances[:net_http].reset!
  end

  it "includes integration module into Net::HTTP" do
    Honeybadger::Plugin.instances[:net_http].load!(config)
    expect(Net::HTTP.ancestors).to include(Honeybadger::Plugins::Net::HTTP)
  end
end
