require 'logger'
require 'honeybadger/backend/server'
require 'honeybadger/config'

describe Honeybadger::Backend::Server do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, api_key: 'abc123') }
  let(:logger) { config.logger }

  subject { described_class.new(config) }

  it { should respond_to :notify }

  describe "#notify" do
    it "returns the response" do
      stub_http
      expect(notify_backend).to be_a Honeybadger::Backend::Response
    end

    context "when encountering exceptions" do
      context "HTTP connection setup problems" do
        it "should not be rescued" do
          proxy = double()
          allow(proxy).to receive(:new).and_raise(NoMemoryError)
          allow(Net::HTTP).to receive(:Proxy).and_return(proxy)
          expect { notify_backend }.to raise_error(NoMemoryError)
        end

        it "should be logged" do
          proxy = double()
          allow(proxy).to receive(:new).and_raise(RuntimeError.new('Snakes!'))
          allow(Net::HTTP).to receive(:Proxy).and_return(proxy)

          expect(logger).to receive(:error).with(/Snakes/)

          expect { notify_backend }.to raise_error(RuntimeError)
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
      subject.notify(:notices, double('Notice', to_json: '{}'))
    end
  end
end
