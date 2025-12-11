require "logger"
require "honeybadger/backend/server"
require "honeybadger/config"

RSpec.describe Honeybadger::Backend::Server do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, api_key: "abc123") }
  let(:logger) { config.logger }
  let(:payload) { double("Notice", to_json: "{}") }

  subject { described_class.new(config) }

  it { should respond_to :notify }
  it { should respond_to :check_in }
  it { should respond_to :event }

  describe "#check_in" do
    it "returns a response" do
      stub_http
      expect(subject.check_in("foobar")).to be_a Honeybadger::Backend::Response
    end
  end

  describe "#notify" do
    it "returns the response" do
      stub_http
      expect(notify_backend).to be_a Honeybadger::Backend::Response
    end

    context "when payload has an api key" do
      before do
        allow(payload).to receive(:api_key).and_return("badgers")
      end

      it "passes the payload api key in extra headers" do
        http = stub_http
        expect(http).to receive(:post).with(anything, anything, hash_including({"X-API-Key" => "badgers"}))
        notify_backend
      end
    end

    context "when payload doesn't have an api key" do
      it "doesn't pass extra headers" do
        http = stub_http
        expect(http).to receive(:post).with(anything, anything, hash_including({"X-API-Key" => "abc123"}))
        notify_backend
      end
    end

    context "when encountering exceptions" do
      context "HTTP connection setup problems" do
        it "should not be rescued" do
          proxy = double
          allow(proxy).to receive(:new).and_raise(NoMemoryError)
          allow(Net::HTTP).to receive(:Proxy).and_return(proxy)
          expect { notify_backend }.to raise_error(NoMemoryError)
        end
      end

      context "connection errors" do
        it "returns Response" do
          http = stub_http
          Honeybadger::Backend::Server::HTTP_ERRORS.each do |error|
            allow(http).to receive(:post).and_raise(error)
            result = notify_backend
            expect(result).to be_a Honeybadger::Backend::Response
            expect(result.code).to eq :error
          end
        end

        it "doesn't fail when posting an http exception occurs" do
          http = stub_http
          Honeybadger::Backend::Server::HTTP_ERRORS.each do |error|
            allow(http).to receive(:post).and_raise(error)
            expect { notify_backend }.not_to raise_error
          end
        end
      end
    end

    def notify_backend
      subject.notify(:notices, payload)
    end
  end

  describe "#event" do
    it "returns the response" do
      stub_http
      expect(send_event).to be_a Honeybadger::Backend::Response
    end

    it "adds auth headers" do
      http = stub_http
      expect(http).to receive(:post).with(anything, anything, hash_including({"X-API-Key" => "abc123"}))
      send_event
    end

    it "serialises json and compresses" do
      http = stub_http
      expect(http).to receive(:post) do |path, body, headers|
        cleartext_body = Zlib::Inflate.inflate(body)
        json = JSON.parse(cleartext_body)
        expect(json["ts"]).to_not be_nil
        expect(json["event_type"]).to eq("checkout")
        expect(json["increment"]).to eq(0)
      end
      send_event
    end

    it "serialises json newline delimited and compresses" do
      http = stub_http
      expect(http).to receive(:post) do |path, body, headers|
        cleartext_body = Zlib::Inflate.inflate(body)

        the_jsons = cleartext_body.split("\n").map { |t| JSON.parse(t) }
        expect(the_jsons.length).to eq(2)

        expect(the_jsons[0]["ts"]).to_not be_nil
        expect(the_jsons[0]["event_type"]).to eq("checkout")
        expect(the_jsons[0]["sum"]).to eq("123.23")
        expect(the_jsons[0]["increment"]).to eq(0)
        expect(the_jsons[1]["increment"]).to eq(1)
      end
      send_event(2)
    end

    def send_event(count = 1)
      payload = []
      count.times { |i| payload << {ts: DateTime.now.new_offset(0).rfc3339, event_type: "checkout", sum: "123.23", increment: i} }
      subject.event(payload)
    end
  end
end
