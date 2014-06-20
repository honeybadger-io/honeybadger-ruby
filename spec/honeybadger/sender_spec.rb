require 'spec_helper'

describe Honeybadger::Sender do
  before { reset_config }
  let(:http) { stub_http }

  it "makes a single request when sending notices" do
    http.should_receive(:post).with(Honeybadger::Sender::NOTICES_URI, kind_of(String), kind_of(Hash))
    Honeybadger.notify(RuntimeError.new('oops!'))
  end

  it "sends a user agent with version number" do
    http  = stub_http
    http.should_receive(:post).with(kind_of(String), kind_of(String), hash_including({'User-Agent' => "HB-Ruby #{Honeybadger::VERSION}; #{RUBY_VERSION}; #{RUBY_PLATFORM}"}))
    send_exception
  end

  it "posts to Honeybadger when using an HTTP proxy" do
    http  = stub_http
    proxy = double(:new => http)
    Net::HTTP.stub(:Proxy).and_return(proxy)

    http.should_receive(:post).with(Honeybadger::Sender::NOTICES_URI, kind_of(String), Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
    Net::HTTP.should_receive(:Proxy).with('some.host', 88, 'login', 'passwd')

    send_exception(:proxy_host => 'some.host',
                   :proxy_port => 88,
                   :proxy_user => 'login',
                   :proxy_pass => 'passwd',
                   :notice => 'asdf')
  end

  it "returns the created group's id on successful posting" do
    stub_http(:body => '{"id":"3799307"}')
    expect(send_exception(:secure => false)).to eq '3799307'
  end

  it "returns nil on failed posting" do
    stub_http(:response => Net::HTTPError)
    expect(send_exception(:secure => false)).to be_nil
  end

  describe '#api_key' do
    context 'api_key is missing' do
      it "logs missing API key and return nil" do
        sender = build_sender(:api_key => nil)
        sender.should_receive(:log).with(:error, /API key/)
        expect(send_exception(:sender => sender, :secure => false)).to be_nil
      end
    end

    context 'notice is a hash' do
      it 'uses api_key from hash when present' do
        sender = build_sender(:api_key => 'asdf')
        http.should_receive(:post).with(Honeybadger::Sender::NOTICES_URI, kind_of(String), hash_including('X-API-Key' => 'zxcv'))
        send_exception(:sender => sender, :notice => { 'api_key' => 'zxcv' })
      end
    end

    context 'notice is a Honeybadger::Notice' do
      it 'uses api_key from notice when present' do
        sender = build_sender(:api_key => 'asdf')
        http.should_receive(:post).with(Honeybadger::Sender::NOTICES_URI, kind_of(String), hash_including('X-API-Key' => 'zxcv'))
        send_exception(:sender => sender, :notice => Honeybadger::Notice.new(:api_key => 'zxcv'))
      end
    end
  end

  context "success response from server" do
    let(:sender) { build_sender }

    before { stub_http }

    it "logs success" do
      sender.should_receive(:log).with(:debug, /Success/, kind_of(Net::HTTPSuccess), kind_of(String))
      send_exception(:sender => sender, :secure => false)
    end

    it "doesn't change features" do
      expect { send_exception(:sender => sender, :secure => false) }.not_to change { Honeybadger.configuration.features }
    end
  end

  context "403 response from server" do
    it "deactivates notices on 403" do
      stub_http(:response => Net::HTTPForbidden.new('1.2', '403', 'Forbidden'))
      sender = build_sender
      expect { send_exception(:sender => sender, :secure => false) }.to change { Honeybadger.configuration.features['notices'] }.to false
    end
  end

  it "logs failure" do
    stub_http(:response => Net::HTTPServerError.new('1.2', '500', 'Internal Error'))
    sender = build_sender
    sender.should_receive(:log).with(:error, /Failure/, kind_of(Net::HTTPServerError), kind_of(String))
    send_exception(:sender => sender, :secure => false)
  end

  context "when encountering exceptions" do
    # TODO: Figure out why nested groups aren't running
    context "HTTP connection setup problems" do
      it "should not be rescued" do
        proxy = double()
        proxy.stub(:new).and_raise(NoMemoryError)
        Net::HTTP.stub(:Proxy).and_return(proxy)
        expect { build_sender.send(:setup_http_connection) }.to raise_error(NoMemoryError)
      end

      it "should be logged" do
        proxy = double()
        proxy.stub(:new).and_raise(RuntimeError)
        Net::HTTP.stub(:Proxy).and_return(proxy)

        sender = build_sender
        sender.should_receive(:log).with(:error, /Failure initializing the HTTP connection/)

        expect { sender.send(:setup_http_connection) }.to raise_error(RuntimeError)
      end
    end

    context "unexpected exception sending problems" do
      it "should be logged" do
        sender  = build_sender
        sender.should_receive(:setup_http_connection).and_raise(RuntimeError)

        sender.should_receive(:log).with(:error, /Error/)
        sender.send_to_honeybadger("stuff")
      end

      it "should log the exception on any error" do
        Honeybadger.configuration.log_exception_on_send_failure = true
        notice = Honeybadger::Notice.new(:exception => Exception.new("bad things"))
        sender = build_sender
        sender.should_receive(:setup_http_connection).and_raise(RuntimeError)
        sender.stub(:log)

        Honeybadger.should_receive(:write_verbose_log).with(/Original Exception:.*bad things/, :error)
        sender.send_to_honeybadger(notice)
      end

      it "should not log the exception on any error by default" do
        notice = Honeybadger::Notice.new(:exception => Exception.new("bad things"))
        sender = build_sender
        sender.should_receive(:setup_http_connection).and_raise(RuntimeError)
        sender.stub(:log)

        Honeybadger.should_not_receive(:write_verbose_log).with(/Original Exception:.*bad things/, :error)
        sender.send_to_honeybadger(notice)
      end

      it "should log the exception on a non-successful HTTP response" do
        Honeybadger.configuration.log_exception_on_send_failure = true
        stub_http(:response => Net::HTTPError)
        notice = Honeybadger::Notice.new(:exception => Exception.new("bad things"))
        sender = build_sender
        sender.stub(:log)

        Honeybadger.should_receive(:write_verbose_log).with(/Original Exception:.*bad things/, :error)
        sender.send_to_honeybadger(notice)
      end


      it "returns nil no matter what" do
        sender  = build_sender
        sender.should_receive(:setup_http_connection).and_raise(LocalJumpError)

        expect { sender.send_to_honeybadger("stuff").should be_nil }.not_to raise_error
      end
    end

    it "returns nil on failed posting" do
      http = stub_http
      http.should_receive(:post).and_raise(Errno::ECONNREFUSED)
      expect(send_exception(:secure => false)).to be_nil
    end

    it "not fail when posting and a timeout exception occurs" do
      http = stub_http
      http.should_receive(:post).and_raise(TimeoutError)
      expect { send_exception(:secure => false) }.not_to raise_error
    end

    it "not fail when posting and a connection refused exception occurs" do
      http = stub_http
      http.should_receive(:post).and_raise(Errno::ECONNREFUSED)
      expect { send_exception(:secure => false) }.not_to raise_error
    end

    it "not fail when posting any http exception occurs" do
      http = stub_http
      Honeybadger::Sender::HTTP_ERRORS.each do |error|
        http.stub(:post).and_raise(error)
        expect { send_exception(:secure => false) }.not_to raise_error
      end
    end
  end

  context "SSL" do
    it "posts to the right url for non-ssl" do
      http = stub_http
      url = "http://api.honeybadger.io:80#{Honeybadger::Sender::NOTICES_URI}"
      uri = URI.parse(url)
      http.should_receive(:post).with(uri.path, anything, Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
      send_exception(:secure => false)
    end

    it "post to the right path for ssl" do
      http = stub_http
      http.should_receive(:post).with(Honeybadger::Sender::NOTICES_URI, anything, Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
      send_exception(:secure => true)
    end

    it "verifies the SSL peer when the use_ssl option is set to true" do
      url = "https://api.honeybadger.io#{Honeybadger::Sender::NOTICES_URI}"
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

  context "network timeouts" do
    it "default the open timeout to 2 seconds" do
      http = stub_http
      http.should_receive(:open_timeout=).with(2)
      send_exception
    end

    it "default the read timeout to 5 seconds" do
      http = stub_http
      http.should_receive(:read_timeout=).with(5)
      send_exception
    end

    it "allow override of the open timeout" do
      http = stub_http
      http.should_receive(:open_timeout=).with(4)
      send_exception(:http_open_timeout => 4)
    end

    it "allow override of the read timeout" do
      http = stub_http
      http.should_receive(:read_timeout=).with(10)
      send_exception(:http_read_timeout => 10)
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
