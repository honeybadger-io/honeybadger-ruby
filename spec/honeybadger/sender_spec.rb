require 'spec_helper'

describe Honeybadger::Sender do
  let(:sender) { build_sender }

  before do
    stub_request(:post, /api\.honeybadger\.io\/v1\/notices/).to_return(:body => '{"id":"123"}')
  end

  describe "#send_to_honeybadger" do
    it "returns the created group's id on successful posting" do
      stub_http(:body => '{"id":"3799307"}')
      expect(send_exception(:secure => false)).to eq '3799307'
    end

    it "returns nil on failed posting" do
      stub_http(:response => Net::HTTPError)
      expect(send_exception(:secure => false)).to be_nil
    end

    it "makes a single request" do
      send_exception
      assert_requested :post, 'https://api.honeybadger.io/v1/notices/', :times => 1
    end

    context "api_key is missing" do
      it "logs missing API key and returns nil" do
        sender = build_sender(:api_key => nil)
        sender.should_receive(:log).with(:error, /API key/)
        expect(send_exception(:sender => sender, :secure => false)).to be_nil
      end
    end

    context "overriding the api_key" do
      context "notice is a hash" do
        it "uses api_key from hash when present" do
          sender = build_sender(:api_key => 'asdf')
          send_exception(:sender => sender, :notice => { 'api_key' => 'zxcv' })
          assert_requested :post, 'https://api.honeybadger.io/v1/notices/', :times => 1, :headers => { 'x-api-key' => 'zxcv' }
        end
      end

      context "notice is a Honeybadger::Notice" do
        it "uses api_key from notice when present" do
          sender = build_sender(:api_key => 'asdf')
          send_exception(:sender => sender, :notice => Honeybadger::Notice.new(:api_key => 'zxcv'))
          assert_requested :post, 'https://api.honeybadger.io/v1/notices/', :times => 1, :headers => { 'x-api-key' => 'zxcv' }
        end
      end
    end

    context "JSON notice" do
      it "ensures valid JSON" do
        stub_http
        data = build_notice_data.to_json
        sender.should_receive(:send_request).with(:notices, JSON.parse(data), anything)
        send_exception(:sender => sender, :notice => data, :secure => false)
      end

      it "logs JSON parse errors and returns nil" do
        sender.should_receive(:log).with(:error, /JSON/)
        expect(send_exception(:sender => sender, :notice => 'adgsh* }')).to be_nil
      end
    end

    context "when an exception is raised" do
      it "logs the exception" do
        sender.stub(:setup_http_connection).and_raise(RuntimeError)
        sender.should_receive(:log).with(:error, /Error/)
        sender.send_to_honeybadger({})
      end

      it "doesn't re-raise exceptions" do
        sender.stub(:setup_http_connection).and_raise(StandardError)
        expect { sender.send_to_honeybadger({}) }.not_to raise_error
      end

      it "returns nil no matter what" do
        sender.stub(:setup_http_connection).and_raise(StandardError)
        expect(sender.send_to_honeybadger({})).to be_nil
      end
    end

    it "doesn't fail when a timeout exception occurs" do
      http = stub_http
      http.should_receive(:post).and_raise(TimeoutError)
      expect { send_exception(:secure => false) }.not_to raise_error
    end

    it "doesn't fail when posting and a connection refused exception occurs" do
      http = stub_http
      http.should_receive(:post).and_raise(Errno::ECONNREFUSED)
      expect { send_exception(:secure => false) }.not_to raise_error
    end

    it "doesn't fail when posting any http exception occurs" do
      http = stub_http
      Honeybadger::HTTP_ERRORS.each do |error|
        http.stub(:post).and_raise(error)
        expect { send_exception(:secure => false) }.not_to raise_error
      end
    end
  end

  describe "#send_request" do
    it "posts to the right url for non-ssl" do
      sender = build_sender(:secure => false)
      http = stub_http
      url = "http://api.honeybadger.io:80/v1/notices/"
      uri = URI.parse(url)
      http.should_receive(:post).with(uri.path, anything, Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
      sender.send(:send_request, :notices, {})
    end

    it "post to the right path for ssl" do
      sender = build_sender(:secure => true)
      http = stub_http
      http.should_receive(:post).with('/v1/notices/', anything, Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
      sender.send(:send_request, :notices, {})
    end

    it "posts to Honeybadger when using an HTTP proxy" do
      http  = stub_http
      proxy = double(:new => http)
      Net::HTTP.stub(:Proxy).and_return(proxy)

      http.should_receive(:post).with('/v1/notices/', kind_of(String), Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
      Net::HTTP.should_receive(:Proxy).with('some.host', 88, 'login', 'passwd')

      sender = build_sender(:proxy_host => 'some.host',
                            :proxy_port => 88,
                            :proxy_user => 'login',
                            :proxy_pass => 'passwd')

      sender.send(:send_request, :notices, {})
    end

    context "successful response" do
      it "logs the success" do
        sender.should_receive(:log).with(:debug, /Success/, kind_of(Net::HTTPSuccess), kind_of(String))
        sender.send(:send_request, :notices, {})
      end

      it "logs the success with API prefix" do
        sender.should_receive(:log).with(:debug, /NOTICES/, kind_of(Net::HTTPSuccess), kind_of(String))
        sender.send(:send_request, :notices, {})
      end
    end

    context "unsuccessful response" do
      it "logs the failure with API prefix" do
        stub_request(:post, /api\.honeybadger\.io\/v1\/notices/).to_return(:status => [429, 'Too Many Requests'])
        sender.should_receive(:log).with(:error, /NOTICES/, kind_of(Net::HTTPResponse), kind_of(String))
        expect { sender.send(:send_request, :notices, {}) }.to raise_error
      end

      it "logs response message on a failure with an invalid body" do
        stub_request(:post, /api\.honeybadger\.io\/v1\/notices/).to_return(:status => [429, 'Too Many Requests'], :body => 'ror":"oh no{s!"}')
        sender.should_receive(:log).with(:error, /Too Many Requests/, kind_of(Net::HTTPResponse), kind_of(String))
        expect { sender.send(:send_request, :notices, {}) }.to raise_error
      end

      it "logs response message on a failure with a body" do
        stub_request(:post, /api\.honeybadger\.io\/v1\/notices/).to_return(:status => [429, 'Too Many Requests'], :body => '{"error":"oh noes!"}')
        sender.should_receive(:log).with(:error, /oh noes!/, kind_of(Net::HTTPResponse), kind_of(String))
        expect { sender.send(:send_request, :notices, {}) }.to raise_error
      end

      it "logs response class on a failure without a body or message" do
        stub_request(:post, /api\.honeybadger\.io\/v1\/notices/).to_return(:status => 429)
        sender.should_receive(:log).with(:error, /#{RUBY_VERSION !~ /^1/ ? 'Net::HTTPTooManyRequests' : 'Net::HTTPClientError'}/, kind_of(Net::HTTPResponse), kind_of(String))
        expect { sender.send(:send_request, :notices, {}) }.to raise_error
      end
    end

    context "HTTP failures" do
      Honeybadger::HTTP_ERRORS.each do |error_class|
        context "#{error_class}" do
          let(:error_class) { error_class }

          it "retries connection up to configured limit" do
            sender.should_receive(:setup_http_connection).exactly(3).times.and_raise(error_class)
            expect { sender.send(:send_request, :notices, :data, :headers) }.to raise_error(Honeybadger::HTTPError)
          end
        end
      end

      context "InvalidResponseError" do
        context "Net::HTTPInternalServerError" do
          it "retries connection up to configured limit" do
            stub_http(:response => Net::HTTPInternalServerError.new('1.2', '500', 'Internal Error')).should_receive(:post).exactly(3).times
            expect { sender.send(:send_request, :notices, {}, {}) }.to raise_error(Honeybadger::InvalidResponseError)
          end
        end

        context "other errors" do
          it "does not retry connection" do
            stub_http(:response => Net::HTTPClientError.new('1.2', '429', 'Too Many Requests')).should_receive(:post).exactly(1).times
            expect { sender.send(:send_request, :notices, {}, {}) }.to raise_error(Honeybadger::InvalidResponseError)
          end
        end
      end
    end
  end

  describe "#setup_http_connection" do
    context "when an exception is raised" do
      it "doesn't rescue the exception" do
        proxy = double()
        proxy.stub(:new).and_raise(NoMemoryError)
        Net::HTTP.stub(:Proxy).and_return(proxy)
        expect { build_sender.send(:setup_http_connection) }.to raise_error(NoMemoryError)
      end

      it "logs the exception" do
        proxy = double()
        proxy.stub(:new).and_raise(RuntimeError)
        Net::HTTP.stub(:Proxy).and_return(proxy)

        sender = build_sender
        sender.should_receive(:log).with(:error, /Failure initializing the HTTP connection/)

        expect { sender.send(:setup_http_connection) }.to raise_error(RuntimeError)
      end
    end

    context "network timeouts" do
      it "default the open timeout to 2 seconds" do
        http = stub_http
        http.should_receive(:open_timeout=).with(2)
        sender.send(:setup_http_connection)
      end

      it "default the read timeout to 5 seconds" do
        http = stub_http
        http.should_receive(:read_timeout=).with(5)
        sender.send(:setup_http_connection)
      end

      it "allow override of the open timeout" do
        http = stub_http
        http.should_receive(:open_timeout=).with(4)
        build_sender(:http_open_timeout => 4).send(:setup_http_connection)
      end

      it "allow override of the read timeout" do
        http = stub_http
        http.should_receive(:read_timeout=).with(10)
        build_sender(:http_read_timeout => 10).send(:setup_http_connection)
      end
    end

    context "SSL" do
      it "verifies the SSL peer when the use_ssl option is set to true" do
        url = "https://api.honeybadger.io/v1/notices/"
        uri = URI.parse(url)

        real_http = Net::HTTP.new(uri.host, uri.port)
        real_http.stub(:post => nil)
        proxy = double(:new => real_http)
        Net::HTTP.stub(:Proxy => proxy)

        File.stub(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(false)

        send_exception(:secure => true)

        expect(real_http.use_ssl?).to be_true
        expect(real_http.verify_mode).to eq OpenSSL::SSL::VERIFY_PEER
        expect(real_http.ca_file).to eq Honeybadger.configuration.local_cert_path
      end

      it "uses the default DEFAULT_CERT_FILE if asked to" do
        File.should_receive(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(true)

        Honeybadger.configure do |config|
          config.secure = true
          config.use_system_ssl_cert_chain = true
        end

        sender = Honeybadger::Sender.new(Honeybadger.configuration)

        expect(sender.use_system_ssl_cert_chain?).to be_true

        http = sender.send(:setup_http_connection)
        expect(http.ca_file).not_to eq Honeybadger.configuration.local_cert_path
      end

      it "verifies the connection when the use_ssl option is set (VERIFY_PEER)" do
        sender  = build_sender(:secure => true)
        http    = sender.send(:setup_http_connection)
        expect(http.verify_mode).to eq OpenSSL::SSL::VERIFY_PEER
      end

      it "uses the default cert (OpenSSL::X509::DEFAULT_CERT_FILE) only if explicitly told to" do
        sender  = build_sender(:secure => true)
        http    = sender.send(:setup_http_connection)

        expect(http.ca_file).to eq Honeybadger.configuration.local_cert_path

        File.stub(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(true)
        sender  = build_sender(:secure => true, :use_system_ssl_cert_chain => true)
        http    = sender.send(:setup_http_connection)

        expect(http.ca_file).not_to eq Honeybadger.configuration.local_cert_path
        expect(http.ca_file).to eq OpenSSL::X509::DEFAULT_CERT_FILE
      end

      it "uses ssl if secure" do
        sender  = build_sender(:secure => true)
        http    = sender.send(:setup_http_connection)
        expect(http.port).to eq 443
      end

      it "does not use ssl if not secure" do
        sender  = build_sender(:secure => false)
        http    = sender.send(:setup_http_connection)
        expect(http.port).to eq 80
      end
    end
  end

  def build_sender(opts = {})
    Honeybadger.configure do |conf|
      opts.each {|opt, value| conf.send(:"#{opt}=", value) }
    end
  end

  def send_exception(args = {})
    notice = args.delete(:notice) || build_notice_data
    sender = args.delete(:sender) || build_sender(args)
    sender.send_to_honeybadger(notice)
  end
end
