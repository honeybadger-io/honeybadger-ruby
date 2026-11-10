require "thor"
require "honeybadger/cli/test"

describe Honeybadger::CLI::Test do
  let(:response) { double("response", body: {id: "abc-123"}.to_json) }
  let(:config) { Honeybadger::Config.new(api_key: "asdf", logger: NULL_LOGGER, backend: :null) }
  let(:options) { {} }

  subject(:cli) { described_class.new(options) }

  before { allow(Honeybadger).to receive(:config).and_return(config) }

  describe "#generate_success_message" do
    it "links to the default UI host" do
      expect(cli.send(:generate_success_message, response)).to eq("⚡ Success: https://app.honeybadger.io/notice/abc-123")
    end

    context "when connection.ui_host is configured" do
      let(:config) { Honeybadger::Config.new(api_key: "asdf", logger: NULL_LOGGER, backend: :null, "connection.ui_host": "eu-app.honeybadger.io") }

      it "links to the configured UI host" do
        expect(cli.send(:generate_success_message, response)).to eq("⚡ Success: https://eu-app.honeybadger.io/notice/abc-123")
      end

      context "during install" do
        let(:options) { {install: true} }

        it "uses the configured UI host in the install message" do
          message = cli.send(:generate_success_message, response)
          expect(message).to include("https://eu-app.honeybadger.io/notice/abc-123")
          expect(message).not_to include("https://app.honeybadger.io")
        end
      end
    end
  end
end
