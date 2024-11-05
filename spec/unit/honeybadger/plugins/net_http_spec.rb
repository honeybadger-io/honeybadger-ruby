require 'honeybadger/plugins/net_http'
require 'honeybadger/config'

describe "Net::HTTP integration" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, :'insights.enabled' => true) }

  before do
    Honeybadger::Plugin.instances[:net_http].reset!
    Honeybadger::Plugin.instances[:net_http].load!(config)
  end

  it "includes integration module into Net::HTTP" do
    expect(Net::HTTP.ancestors).to include(Honeybadger::Plugins::Net::HTTP)
  end

  describe "event payload" do
    before { stub_request(:get, "http://example.com/") }

    context "report domain only" do
      it "contains a domain" do
        expect(Honeybadger).to receive(:event).with('request.net_http', hash_including({method: "GET", status: 200, host: "example.com"}))
        expect(Honeybadger).to receive(:gauge).with('duration.request', hash_including({method: "GET", status: 200, host: "example.com"}))
        Net::HTTP.get(URI.parse('http://example.com'))
      end
    end

    context "report domain and full url" do
      before { config[:'net_http.insights.full_url'] = true }

      it "contains a domain and url" do
        expect(Honeybadger).to receive(:event).with('request.net_http', hash_including({method: "GET", status: 200, url: "http://example.com", host: "example.com"}))
        expect(Honeybadger).to receive(:gauge).with('duration.request', hash_including({method: "GET", status: 200, host: "example.com"}))
        Net::HTTP.get(URI.parse('http://example.com'))
      end
    end
  end
end
