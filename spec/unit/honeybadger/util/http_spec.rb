require 'net/http'
require 'logger'
require 'honeybadger/util/http'
require 'honeybadger/config'

describe Honeybadger::Util::HTTP do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, api_key: 'abc123') }
  let(:logger) { config.logger }

  subject { described_class.new(config) }

  it { should respond_to :post }

  it "sends a user agent with version number" do
    http  = stub_http
    expect(http).to receive(:post).with(kind_of(String), kind_of(String), hash_including({'User-Agent' => "HB-Ruby #{Honeybadger::VERSION}; #{RUBY_VERSION}; #{RUBY_PLATFORM}"}))
    http_post
  end

  context "when proxy settings are configured" do
    let(:config) {
      Honeybadger::Config.new({
        :api_key => 'abc123',
        :'connection.proxy_host' => 'some.host',
        :'connection.proxy_port' => 88,
        :'connection.proxy_user' => 'login',
        :'connection.proxy_pass' => 'passwd'
      })
    }

    it "posts to Honeybadger when using an HTTP proxy" do
      http  = stub_http
      proxy = double(new: http)
      allow(Net::HTTP).to receive(:Proxy).and_return(proxy)

      expect(http).to receive(:post).with('/v1/foo', kind_of(String), Honeybadger::Util::HTTP::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
      expect(Net::HTTP).to receive(:Proxy).with('some.host', 88, 'login', 'passwd')

      http_post
    end
  end

  it "returns the response" do
    stub_http
    expect(http_post).to be_a Net::HTTPResponse
  end

  context "success response from server" do
    let(:sender) { build_sender }

    before { stub_http }

    it "logs success" do
      expect(logger).to receive(:debug).with(/code=200/)
      http_post
    end
  end

  context "non-success response from server" do
    it "logs failure" do
      stub_http(response: Net::HTTPClientError.new('1.2', '429', 'Too Many Requests'))
      expect(logger).to receive(:debug).with(/code=429/)
      http_post
    end
  end

  context "failure response from server" do
    it "logs failure" do
      stub_http(response: Net::HTTPServerError.new('1.2', '500', 'Internal Error'))
      expect(logger).to receive(:debug).with(/code=500/)
      http_post
    end
  end

  context "when encountering exceptions" do
    context "HTTP connection setup problems" do
      it "should not be rescued" do
        proxy = double()
        allow(proxy).to receive(:new).and_raise(NoMemoryError)
        allow(Net::HTTP).to receive(:Proxy).and_return(proxy)
        expect { http_post }.to raise_error(NoMemoryError)
      end
    end

    # context "connection errors" do
    #   it "returns nil" do
    #     http = stub_http
    #     Honeybadger::Backend::Server::HTTP_ERRORS.each do |error|
    #       allow(http).to receive(:post).and_raise(error)
    #       expect(http_post).to be_nil
    #     end
    #   end

    #   it "doesn't fail when posting an http exception occurs" do
    #     http = stub_http
    #     Honeybadger::Backend::Server::HTTP_ERRORS.each do |error|
    #       allow(http).to receive(:post).and_raise(error)
    #       expect { http_post }.not_to raise_error
    #     end
    #   end
    # end
  end

  context "SSL" do
    it "posts to the right url for non-ssl" do
      config[:'connection.secure'] = false
      http = stub_http
      url = "http://api.honeybadger.io:80/v1/foo"
      uri = URI.parse(url)
      expect(http).to receive(:post).with(uri.path, anything, Honeybadger::Util::HTTP::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
      http_post
    end

    it "post to the right path for ssl" do
      http = stub_http
      expect(http).to receive(:post).with('/v1/foo', anything, Honeybadger::Util::HTTP::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
      http_post
    end

    it "verifies the SSL peer when the use_ssl option is set to true" do
      url = "https://api.honeybadger.io/v1/foo"
      uri = URI.parse(url)

      real_http = Net::HTTP.new(uri.host, uri.port)
      allow(real_http).to receive(:post).and_return(double(code: '200'))
      proxy = double(new: real_http)
      allow(Net::HTTP).to receive(:Proxy).and_return(proxy)

      allow(File).to receive(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(false)

      http_post

      expect(real_http.use_ssl?).to eq true
      expect(real_http.verify_mode).to eq OpenSSL::SSL::VERIFY_PEER
      expect(real_http.ca_file).to eq config.local_cert_path
    end

    it "uses the default DEFAULT_CERT_FILE if asked to" do
      expect(File).to receive(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(true)
      config[:'connection.system_ssl_cert_chain'] = true

      http = subject.send(:setup_http_connection)
      expect(http.ca_file).not_to eq config.local_cert_path
      expect(http.ca_file).to eq OpenSSL::X509::DEFAULT_CERT_FILE
    end

    it "uses a custom ca bundle if asked to" do
      config[:'connection.ssl_ca_bundle_path'] = '/test/blargh.crt'

      http = subject.send(:setup_http_connection)
      expect(http.ca_file).not_to eq config.local_cert_path
      expect(http.ca_file).to eq '/test/blargh.crt'
    end

    it "uses the default cert (OpenSSL::X509::DEFAULT_CERT_FILE) only if explicitly told to" do
      allow(File).to receive(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(true)
      http = subject.send(:setup_http_connection)

      expect(http.ca_file).to eq config.local_cert_path
      expect(http.ca_file).not_to eq OpenSSL::X509::DEFAULT_CERT_FILE
    end

    it "verifies the connection when the use_ssl option is set (VERIFY_PEER)" do
      http = subject.send(:setup_http_connection)
      expect(http.verify_mode).to eq OpenSSL::SSL::VERIFY_PEER
    end

    it "uses ssl if secure" do
      http = subject.send(:setup_http_connection)
      expect(http.port).to eq 443
    end

    it "does not use ssl if not secure" do
      config[:'connection.secure'] = false
      http = subject.send(:setup_http_connection)
      expect(http.port).to eq 80
    end
  end

  context "network timeouts" do
    it "default the open timeout to 2 seconds" do
      http = stub_http
      expect(http).to receive(:open_timeout=).with(2)
      http_post
    end

    it "default the read timeout to 5 seconds" do
      http = stub_http
      expect(http).to receive(:read_timeout=).with(5)
      http_post
    end

    it "allow override of the open timeout" do
      config[:'connection.http_open_timeout'] = 4
      http = stub_http
      expect(http).to receive(:open_timeout=).with(4)
      http_post
    end

    it "allow override of the read timeout" do
      config[:'connection.http_read_timeout'] = 10
      http = stub_http
      expect(http).to receive(:read_timeout=).with(10)
      http_post
    end
  end

  def http_post
    subject.post('/v1/foo', double('Notice', to_json: '{}'))
  end
end
