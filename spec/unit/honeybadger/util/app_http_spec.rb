require 'net/http'
require 'logger'
require 'honeybadger/util/http'
require 'honeybadger/config'
require 'base64'

describe Honeybadger::Util::AppHTTP do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, personal_auth_token: 'abc123') }
  let(:logger) { config.logger }

  subject { described_class.new(config) }

  it { should respond_to :post }
  it { should respond_to :get }
  it { should respond_to :put }
  it { should respond_to :delete }
  
  it "sends auth token with request" do
    http  = stub_http
    auth_string = Base64.encode64("abc123:")
    expect(http).to receive(:get).with(kind_of(String), hash_including({'Authorization' => "Basic #{auth_string}"}))
    subject.get("/v2/projects/1234/check_ins")
  end
end
