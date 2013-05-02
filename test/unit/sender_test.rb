require 'test_helper'

class SenderTest < Test::Unit::TestCase

  include SettingEnvironment

  def setup
    reset_config
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

  def stub_http(options = {})
    response = options[:response] || Net::HTTPSuccess.new('1.2', '200', 'OK')
    response.stubs(:body => options[:body] || '{"id":"1234"}')
    http = stub(:post          => response,
                :read_timeout= => nil,
                :open_timeout= => nil,
                :ca_file=      => nil,
                :verify_mode=  => nil,
                :use_ssl=      => nil)
    Net::HTTP.stubs(:new => http)
    http
  end

  should "post to Honeybadger when using an HTTP proxy" do
    response = stub(:body => 'body')
    http     = stub(:post          => response,
                    :read_timeout= => nil,
                    :open_timeout= => nil,
                    :use_ssl=      => nil,
                    :ca_file=      => nil,
                    :verify_mode=  => nil)
    proxy    = stub(:new => http)
    Net::HTTP.stubs(:Proxy => proxy)

    url = "http://api.honeybadger.io:80#{Honeybadger::Sender::NOTICES_URI}"
    uri = URI.parse(url)

    proxy_host = 'some.host'
    proxy_port = 88
    proxy_user = 'login'
    proxy_pass = 'passwd'

    send_exception(:proxy_host => proxy_host,
                   :proxy_port => proxy_port,
                   :proxy_user => proxy_user,
                   :proxy_pass => proxy_pass)
    assert_received(http, :post) do |expect| 
      expect.with(uri.path, anything, Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'}))
    end
    assert_received(Net::HTTP, :Proxy) do |expect|
      expect.with(proxy_host, proxy_port, proxy_user, proxy_pass)
    end
  end

  should "return the created group's id on successful posting" do
    http = stub_http(:body => '{"id":"3799307"}')
    assert_equal "3799307", send_exception(:secure => false)
  end

  should "return nil on failed posting" do
    http = stub_http(:response => Net::HTTPServerError.new('1.2', '500', 'Internal Error'))
    assert_equal nil, send_exception(:secure => false)
  end

  should "should log success" do
    http = stub_http
    sender = build_sender
    sender.expects(:log).with(:debug, includes('Success'), kind_of(Net::HTTPSuccess), kind_of(String))
    send_exception(:sender => sender, :secure => false)
  end

  should "should log failure" do
    http = stub_http(:response => Net::HTTPServerError.new('1.2', '500', 'Internal Error'))
    sender = build_sender
    sender.expects(:log).with(:error, includes('Failure'), kind_of(Net::HTTPServerError), kind_of(String))
    send_exception(:sender => sender, :secure => false)
  end

  context "when encountering exceptions: " do
    context "HTTP connection setup problems" do
      should "not be rescued" do
        proxy = stub()
        proxy.stubs(:new).raises(NoMemoryError)
        Net::HTTP.stubs(:Proxy => proxy)

        assert_raise NoMemoryError do
          build_sender.send(:setup_http_connection)
        end
      end

      should "be logged" do
        proxy = stub()
        proxy.stubs(:new).raises(RuntimeError)
        Net::HTTP.stubs(:Proxy => proxy)

        sender = build_sender
        sender.expects(:log).with(:error, includes('Failure initializing the HTTP connection'))

        assert_raise RuntimeError do
          sender.send(:setup_http_connection)
        end

      end
    end

    context "unexpected exception sending problems" do
      should "be logged" do
        sender  = build_sender
        sender.stubs(:setup_http_connection).raises(RuntimeError.new)

        sender.expects(:log).with(:error, includes('Error'))
        sender.send_to_honeybadger("stuff")
      end

      should "return nil no matter what" do
        sender  = build_sender
        sender.stubs(:setup_http_connection).raises(LocalJumpError)

        assert_nothing_thrown do
          assert_nil sender.send_to_honeybadger("stuff")
        end
      end
    end

    should "return nil on failed posting" do
      http = stub_http
      http.stubs(:post).raises(Errno::ECONNREFUSED)
      assert_equal nil, send_exception(:secure => false)
    end

    should "not fail when posting and a timeout exception occurs" do
      http = stub_http
      http.stubs(:post).raises(TimeoutError)
      assert_nothing_thrown do
        send_exception(:secure => false)
      end
    end

    should "not fail when posting and a connection refused exception occurs" do
      http = stub_http
      http.stubs(:post).raises(Errno::ECONNREFUSED)
      assert_nothing_thrown do
        send_exception(:secure => false)
      end
    end

    should "not fail when posting any http exception occurs" do
      http = stub_http
      Honeybadger::Sender::HTTP_ERRORS.each do |error|
        http.stubs(:post).raises(error)
        assert_nothing_thrown do
          send_exception(:secure => false)
        end
      end
    end
  end

  context "SSL" do
    should "post to the right url for non-ssl" do
      http = stub_http
      url = "http://api.honeybadger.io:80#{Honeybadger::Sender::NOTICES_URI}"
      uri = URI.parse(url)
      send_exception(:secure => false)
      assert_received(http, :post) {|expect| expect.with(uri.path, anything, Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'})) }
    end

    should "post to the right path for ssl" do
      http = stub_http
      send_exception(:secure => true)
      assert_received(http, :post) {|expect| expect.with(Honeybadger::Sender::NOTICES_URI, anything, Honeybadger::HEADERS.merge({ 'X-API-Key' => 'abc123'})) }
    end

    should "verify the SSL peer when the use_ssl option is set to true" do
      url = "https://api.honeybadger.io#{Honeybadger::Sender::NOTICES_URI}"
      uri = URI.parse(url)

      real_http = Net::HTTP.new(uri.host, uri.port)
      real_http.stubs(:post => nil)
      proxy = stub(:new => real_http)
      Net::HTTP.stubs(:Proxy => proxy)
      File.stubs(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).returns(false)

      send_exception(:secure => true)
      assert(real_http.use_ssl?)
      assert_equal(OpenSSL::SSL::VERIFY_PEER,        real_http.verify_mode)
      assert_equal(Honeybadger.configuration.local_cert_path, real_http.ca_file)
    end

    should "use the default DEFAULT_CERT_FILE if asked to" do
      File.expects(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).returns(true)

      Honeybadger.configure do |config|
        config.secure = true
        config.use_system_ssl_cert_chain = true
      end

      sender = Honeybadger::Sender.new(Honeybadger.configuration)

      assert(sender.use_system_ssl_cert_chain?)

      http    = sender.send(:setup_http_connection)
      assert_not_equal http.ca_file, Honeybadger.configuration.local_cert_path
    end

    should "verify the connection when the use_ssl option is set (VERIFY_PEER)" do
      sender  = build_sender(:secure => true)
      http    = sender.send(:setup_http_connection)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, http.verify_mode)
    end

    should "use the default cert (OpenSSL::X509::DEFAULT_CERT_FILE) only if explicitly told to" do
      sender  = build_sender(:secure => true)
      http    = sender.send(:setup_http_connection)

      assert_equal(Honeybadger.configuration.local_cert_path, http.ca_file)

      File.stubs(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).returns(true)
      sender  = build_sender(:secure => true, :use_system_ssl_cert_chain => true)
      http    = sender.send(:setup_http_connection)

      assert_not_equal(Honeybadger.configuration.local_cert_path, http.ca_file)
      assert_equal(OpenSSL::X509::DEFAULT_CERT_FILE, http.ca_file)
    end

    should "connect to the right port for ssl" do
      stub_http
      send_exception(:secure => true)
      assert_received(Net::HTTP, :new) {|expect| expect.with("api.honeybadger.io", 443) }
    end

    should "connect to the right port for non-ssl" do
      stub_http
      send_exception(:secure => false)
      assert_received(Net::HTTP, :new) {|expect| expect.with("api.honeybadger.io", 80) }
    end

    should "use ssl if secure" do
      stub_http
      send_exception(:secure => true, :host => 'example.org')
      assert_received(Net::HTTP, :new) {|expect| expect.with('example.org', 443) }
    end

    should "not use ssl if not secure" do
      stub_http
      send_exception(:secure => false, :host => 'example.org')
      assert_received(Net::HTTP, :new) {|expect| expect.with('example.org', 80) }
    end
  end

  context "network timeouts" do
    should "default the open timeout to 2 seconds" do
      http = stub_http
      send_exception
      assert_received(http, :open_timeout=) {|expect| expect.with(2) }
    end

    should "default the read timeout to 5 seconds" do
      http = stub_http
      send_exception
      assert_received(http, :read_timeout=) {|expect| expect.with(5) }
    end

    should "allow override of the open timeout" do
      http = stub_http
      send_exception(:http_open_timeout => 4)
      assert_received(http, :open_timeout=) {|expect| expect.with(4) }
    end

    should "allow override of the read timeout" do
      http = stub_http
      send_exception(:http_read_timeout => 10)
      assert_received(http, :read_timeout=) {|expect| expect.with(10) }
    end
  end

  context "development sender" do
    should "write to debug log" do
      Honeybadger.stubs(:write_verbose_log)
      sender = set_development_env
      sender.send_to_honeybadger('example')
      assert_logged /^example$/
      assert_received(Net::HTTP, :new) {|expect| expect.never }
    end

    should "use development notification sender" do
      set_development_env
      assert_equal Honeybadger::DevelopmentSender, Honeybadger.sender.class
    end

    should "explicitly set test notification sender" do
      Honeybadger.configure do |config|
        config.environment_name = 'development'
        config.delivery_method = :test
      end
      assert_equal Honeybadger::TestSender, Honeybadger.sender.class
    end
  end

  context "test sender" do
    should "collect notices" do
      notice = Honeybadger::Notice.new(:error_message => 'example')
      sender = set_test_env
      sender.send_to_honeybadger(notice)
      assert_equal 'example', Honeybadger.sender.notices.last.error_message
    end

    should "use test notification sender" do
      set_test_env
      assert_equal Honeybadger::TestSender, Honeybadger.sender.class
    end

    should "explicitly set development notification sender" do
      Honeybadger.configure do |config|
        config.environment_name = 'test'
        config.delivery_method = :development
      end
      assert_equal Honeybadger::DevelopmentSender, Honeybadger.sender.class
    end
  end

  context "production sender" do
    should "use production notification sender" do
      set_public_env
      assert_equal Honeybadger::Sender, Honeybadger.sender.class
    end

  end

end
