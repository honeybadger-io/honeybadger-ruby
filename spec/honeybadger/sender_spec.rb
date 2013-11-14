require 'spec_helper'

describe Honeybadger::Sender do
  before { reset_config }
  before do
    stub_request(:post, /api\.honeybadger\.io\/v1\/notices/).to_return(:body => '{"id":"123"}')
  end

  it "it makes a single request when sending notices" do
    Honeybadger.notify(RuntimeError.new('oops!'))
    assert_requested :post, 'https://api.honeybadger.io/v1/notices/', :times => 1
  end

  it "posts to Honeybadger when using an HTTP proxy" do
    post = double(:headers => {})
    http = stub_http
    http.stub(:post).and_yield(post).and_return(false)

    url = "http://api.honeybadger.io:80#{Honeybadger::Sender::NOTICES_URI}"
    uri = URI.parse(url)

    post.should_receive(:url).with(uri.path)
    post.should_receive(:body=).with('asdf')

    Faraday.should_receive(:new).
      with(hash_including(:proxy => { :uri => 'https://some.host:88', :user => 'login', :password => 'passwd' })).and_return(http)

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
    stub_http(:response => Faraday::Response.new(:status => 500))
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
        send_exception(:sender => sender, :notice => { 'api_key' => 'zxcv' })
        assert_requested :post, 'https://api.honeybadger.io/v1/notices/', :times => 1, :headers => { 'x-api-key' => 'zxcv' }
      end
    end

    context 'notice is a Honeybadger::Notice' do
      it 'uses api_key from notice when present' do
        sender = build_sender(:api_key => 'asdf')
        send_exception(:sender => sender, :notice => Honeybadger::Notice.new(:api_key => 'zxcv'))
        assert_requested :post, 'https://api.honeybadger.io/v1/notices/', :times => 1, :headers => { 'x-api-key' => 'zxcv' }
      end
    end
  end

  it "logs success" do
    stub_http
    sender = build_sender
    sender.should_receive(:log).with(:debug, /Success/, kind_of(Faraday::Response), kind_of(String))
    send_exception(:sender => sender, :secure => false)
  end

  it "logs failure" do
    stub_http(:response => Faraday::Response.new(:status => 500))
    sender = build_sender
    sender.should_receive(:log).with(:error, /Failure/, kind_of(Faraday::Response), kind_of(String))
    send_exception(:sender => sender, :secure => false)
  end

  context "when encountering exceptions" do
    # TODO: Figure out why nested groups aren't running
    context "HTTP connection setup problems" do
      it "should not be rescued" do
        Faraday.should_receive(:new).and_raise(NoMemoryError)
        expect { build_sender.send(:client) }.to raise_error(NoMemoryError)
      end

      it "should be logged" do
        Faraday.should_receive(:new).and_raise(RuntimeError)

        sender = build_sender
        sender.should_receive(:log).with(:error, /Failure initializing the HTTP connection/)

        expect { sender.send(:client) }.to raise_error(RuntimeError)
      end
    end

    context "unexpected exception sending problems" do
      it "should be logged" do
        sender  = build_sender
        sender.should_receive(:client).and_raise(RuntimeError)

        sender.should_receive(:log).with(:error, /Error/)
        sender.send_to_honeybadger("stuff")
      end

      it "returns nil no matter what" do
        sender  = build_sender
        sender.should_receive(:client).and_raise(LocalJumpError)

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
      post = double(:body= => nil, :headers => {})
      http.should_receive(:post).and_yield(post)
      post.should_receive(:url).with(uri.path)
      send_exception(:secure => false)
    end

    it "post to the right path for ssl" do
      http = stub_http
      post = double(:body= => nil, :headers => {})
      http.should_receive(:post).and_yield(post)
      post.should_receive(:url).with(Honeybadger::Sender::NOTICES_URI)
      send_exception(:secure => true)
    end

    it "verifies the SSL peer when the use_ssl option is set to true" do
      url = "https://api.honeybadger.io#{Honeybadger::Sender::NOTICES_URI}"

      real_http = Faraday.new(:url => url)
      real_http.stub(:post => nil)
      Faraday.stub(:new).and_return(real_http)

      File.stub(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(false)

      send_exception(:secure => true)

      expect(real_http.ssl).not_to be_empty
      expect(real_http.ssl[:verify_mode]).to eq OpenSSL::SSL::VERIFY_PEER
      expect(real_http.ssl[:ca_file]).to eq Honeybadger.configuration.local_cert_path
    end

    it "uses the default DEFAULT_CERT_FILE if asked to" do
      File.should_receive(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(true)

      Honeybadger.configure do |config|
        config.secure = true
        config.use_system_ssl_cert_chain = true
      end

      sender = Honeybadger::Sender.new(Honeybadger.configuration)

      expect(sender.use_system_ssl_cert_chain?).to be_true

      http    = sender.send(:client)
      expect(http.ssl[:ca_file]).not_to eq Honeybadger.configuration.local_cert_path
    end

    it "verifies the connection when the use_ssl option is set (VERIFY_PEER)" do
      sender  = build_sender(:secure => true)
      http    = sender.send(:client)
      expect(http.ssl[:verify_mode]).to eq OpenSSL::SSL::VERIFY_PEER
    end

    it "uses the default cert (OpenSSL::X509::DEFAULT_CERT_FILE) only if explicitly told to" do
      sender  = build_sender(:secure => true)
      http    = sender.send(:client)

      expect(http.ssl[:ca_file]).to eq Honeybadger.configuration.local_cert_path

      File.stub(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(true)
      sender  = build_sender(:secure => true, :use_system_ssl_cert_chain => true)
      http    = sender.send(:client)

      expect(http.ssl[:ca_file]).not_to eq Honeybadger.configuration.local_cert_path
      expect(http.ssl[:ca_file]).to eq OpenSSL::X509::DEFAULT_CERT_FILE
    end

    it "uses ssl if secure" do
      sender  = build_sender(:secure => true)
      http    = sender.send(:client)
      expect(http.port).to eq 443
    end

    it "does not use ssl if not secure" do
      sender  = build_sender(:secure => false)
      http    = sender.send(:client)
      expect(http.port).to eq 80
    end
  end

  context "network timeouts" do
    it "default the open timeout to 2 seconds" do
      Faraday.should_receive(:new).with(hash_including({ :request => hash_including({ :open_timeout => 2 }) }))
      send_exception
    end

    it "default the read timeout to 5 seconds" do
      Faraday.should_receive(:new).with(hash_including({ :request => hash_including({ :timeout => 5 }) }))
      send_exception
    end

    it "allow override of the open timeout" do
      Faraday.should_receive(:new).with(hash_including({ :request => hash_including({ :open_timeout => 4 }) }))
      send_exception(:http_open_timeout => 4)
    end

    it "allow override of the read timeout" do
      Faraday.should_receive(:new).with(hash_including({ :request => hash_including({ :timeout => 10 }) }))
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
