require 'test_helper'
require 'json'

class NoticeTest < Test::Unit::TestCase
  def configure
    Honeybadger::Configuration.new.tap do |config|
      config.api_key = 'abc123def456'
    end
  end

  def build_notice(args = {})
    configuration = args.delete(:configuration) || configure
    Honeybadger::Notice.new(configuration.merge(args))
  end

  def stub_request(attrs = {})
    stub('request', { :parameters  => { 'one' => 'two' },
                      :protocol    => 'http',
                      :host        => 'some.host',
                      :request_uri => '/some/uri',
                      :session     => { :to_hash => { 'a' => 'b' } },
                      :env         => { 'three' => 'four' } }.update(attrs))
  end

  should "deliver to sender" do
    sender = stub_sender!
    notice = build_notice
    notice.stubs(:to_json => { :foo => 'bar' })

    notice.deliver

    assert_received(sender, :send_to_honeybadger) { |expect| expect.with(notice) }
  end

  should "generate json from as_json template" do
    notice = build_notice
    hash = {'foo' => 'bar'}
    notice.expects(:as_json).once.returns(hash)
    json = notice.to_json

    payload = nil
    assert_nothing_raised do
      payload = JSON.parse(json)
    end

    assert_equal payload, hash
  end

  should "accept a project root" do
    project_root = '/path/to/project'
    notice = build_notice(:project_root => project_root)
    assert_equal project_root, notice.project_root
  end

  should "accept a component" do
    assert_equal 'users_controller', build_notice(:component => 'users_controller').controller
  end

  should "alias the component as controller" do
    assert_equal 'users_controller', build_notice(:controller => 'users_controller').component
    assert_equal 'users_controller', build_notice(:component => 'users_controller').controller
  end

  should "accept a action" do
    assert_equal 'index', build_notice(:action => 'index').action
  end

  should "accept source excerpt radius" do
    assert_equal 3, build_notice(:source_extract_radius => 3).source_extract_radius
  end

  should "accept a url" do
    url = 'http://some.host/uri'
    notice = build_notice(:url => url)
    assert_equal url, notice.url
  end

  should "set the host name" do
    notice = build_notice
    assert_equal hostname, notice.hostname
  end

  context "custom fingerprint" do
    should "include nil fingerprint when no fingerprint is specified" do
      notice = build_notice
      assert_equal nil, notice.fingerprint
    end

    should "accepts fingerprint as string" do
      notice = build_notice({ :fingerprint => 'foo' })
      assert_equal 'foo', notice.fingerprint
    end

    should "accepts fingerprint responding to #call" do
      notice = build_notice({ :fingerprint => mock(:call => 'foo') })
      assert_equal 'foo', notice.fingerprint
    end
  end

  context "with a backtrace" do
    setup do
      @source = <<-RUBY
        $:<<'lib'
        require 'honeybadger'

        begin
          raise StandardError
        rescue => e
          puts Honeybadger::Notice.new(exception: e).backtrace.to_json
        end
      RUBY

      @backtrace_array = ["my/file/backtrace:3",
                          "test/honeybadger/rack_test.rb:2:in `build_exception'",
                   "test/honeybadger/rack_test.rb:52:in `test_delivers_exception_from_rack'",
                   "foo/bar/baz.rb:28:in `run'"]

      @exception = build_exception
      @exception.set_backtrace(@backtrace_array)
    end

    should "pass its backtrace filters for parsing" do
      Honeybadger::Backtrace.expects(:parse).with(@backtrace_array, {:filters => 'foo'}).returns(mock(:lines => []))

      notice = Honeybadger::Notice.new({:exception => @exception, :backtrace_filters => 'foo'})
    end

    should "pass its backtrace line filters for parsing" do
      @backtrace_array.each do |line|
        Honeybadger::Backtrace::Line.expects(:parse).with(line, {:filters => 'foo'})
      end

      notice = Honeybadger::Notice.new({:exception => @exception, :backtrace_filters => 'foo'})
    end

    should "accept a backtrace from an exception or hash" do
      backtrace = Honeybadger::Backtrace.parse(@backtrace_array)
      notice_from_exception = build_notice(:exception => @exception)

      assert_equal backtrace,
        notice_from_exception.backtrace,
        "backtrace was not correctly set from an exception"

      notice_from_hash = build_notice(:backtrace => @backtrace_array)
      assert_equal backtrace,
        notice_from_hash.backtrace,
        "backtrace was not correctly set from a hash"
    end

    context "without application trace" do
      setup do
        Honeybadger.configuration.project_root = '/foo/bar'
        @string_io = StringIO.new(@source)
        File.stubs(:exists?).with('my/file/backtrace').returns true
        File.stubs(:open).with('my/file/backtrace').yields @string_io
      end

      should "include source extract from backtrace" do
        backtrace = Honeybadger::Backtrace.parse(@backtrace_array)
        notice_from_exception = build_notice(:exception => @exception)
        @string_io.rewind

        assert_not_equal notice_from_exception.source_extract, {}, 'Expected backtrace source extract to be found'
        assert_equal backtrace.lines.first.source, notice_from_exception.source_extract
      end
    end

    context 'with an application trace' do
      setup do
        Honeybadger.configuration.project_root = 'test/honeybadger/'

        @string_io = StringIO.new(@source)
        File.stubs(:exists?).with('test/honeybadger/rack_test.rb').returns true
        File.stubs(:open).with('test/honeybadger/rack_test.rb').yields @string_io
      end

      should "include source extract from first line of application trace" do
        backtrace = Honeybadger::Backtrace.parse(@backtrace_array)
        notice_from_exception = build_notice(:exception => @exception)
        @string_io.rewind

        assert_not_equal notice_from_exception.source_extract, {}, 'Expected backtrace source extract to be found'
        assert_equal backtrace.lines[1].source, notice_from_exception.source_extract
      end
    end
  end

  should "Use source extract from view when reporting an ActionView::Template::Error" do
    # TODO: I would like to stub out a real ActionView::Template::Error, but we're
    # currently locked at actionpack 2.3.8. Perhaps if one day we upgrade...
    source = <<-ERB
      1:   <%= current_user.name %>
      2: </div>
      3: 
      4: <div>
    ERB
    exception = build_exception
    exception.stubs(:source_extract).returns(source)
    notice = Honeybadger::Notice.new({:exception => exception})

    assert_equal({ '1' => '  <%= current_user.name %>', '2' => '</div>', '3' => '', '4' => '<div>'}, notice.source_extract)
  end

  should "set the error class from an exception or hash" do
    assert_accepts_exception_attribute :error_class do |exception|
      exception.class.name
    end
  end

  should "set the error message from an exception or hash" do
    assert_accepts_exception_attribute :error_message do |exception|
      "#{exception.class.name}: #{exception.message}"
    end
  end

  should "accept parameters from a request or hash" do
    parameters = { 'one' => 'two' }
    notice_from_hash = build_notice(:parameters => parameters)
    assert_equal notice_from_hash.parameters, parameters
  end

  should "accept session data from a session[:data] hash" do
    data = { 'one' => 'two' }
    notice = build_notice(:session => { :data => data })
    assert_equal data, notice.session_data
  end

  should "accept session data from a session_data hash" do
    data = { 'one' => 'two' }
    notice = build_notice(:session_data => data)
    assert_equal data, notice.session_data
  end

  should "accept an environment name" do
    assert_equal 'development', build_notice(:environment_name => 'development').environment_name
  end

  should "accept CGI data from a hash" do
    data = { 'string' => 'value' }
    notice = build_notice(:cgi_data => data)
    assert_equal data, notice.cgi_data, "should take CGI data from a hash"
  end

  should "accept notifier information" do
    params = { :notifier_name    => 'a name for a notifier',
               :notifier_version => '1.0.5',
               :notifier_url     => 'http://notifiers.r.us/download' }
    notice = build_notice(params)
    assert_equal params[:notifier_name], notice.notifier_name
    assert_equal params[:notifier_version], notice.notifier_version
    assert_equal params[:notifier_url], notice.notifier_url
  end

  should "set sensible defaults without an exception" do
    backtrace = Honeybadger::Backtrace.parse(build_backtrace_array)
    notice = build_notice(:backtrace => build_backtrace_array)

    assert_equal 'Notification', notice.error_message
    assert_array_starts_with backtrace.lines, notice.backtrace.lines
    assert_equal({}, notice.parameters)
    assert_equal({}, notice.session_data)
  end

  should "use the caller as the backtrace for an exception without a backtrace" do
    filters = Honeybadger::Configuration.new.backtrace_filters
    backtrace = Honeybadger::Backtrace.parse(caller, :filters => filters)
    notice = build_notice(:exception => StandardError.new('error'), :backtrace => nil)

    assert_array_starts_with backtrace.lines, notice.backtrace.lines
  end

  should "convert unserializable objects to strings" do
    assert_serializes_hash(:parameters)
    assert_serializes_hash(:cgi_data)
    assert_serializes_hash(:session_data)
  end

  should "filter parameters" do
    assert_filters_hash(:parameters)
  end

  should "filter cgi data" do
    assert_filters_hash(:cgi_data)
  end

  should "filter session" do
    assert_filters_hash(:session_data)
  end

  should "remove rack.request.form_vars" do
    original = {
      "rack.request.form_vars" => "story%5Btitle%5D=The+TODO+label",
      "abc" => "123"
    }

    notice = build_notice(:cgi_data => original)
    assert_equal({"abc" => "123"}, notice.cgi_data)
  end

  should "not send empty request data" do
    notice = build_notice
    assert_nil notice.url
    assert_nil notice.controller
    assert_nil notice.action

    json = notice.to_json
    payload = JSON.parse(json)
    assert_nil payload['request']['url']
    assert_nil payload['request']['component']
    assert_nil payload['request']['action']
    assert_nil payload['request']['user']
  end

  %w(url controller action).each do |var|
    should "send a request if #{var} is present" do
      notice = build_notice(var.to_sym => 'value')
      json = notice.to_json
      payload = JSON.parse(json)
      assert_not_nil payload['request']
    end
  end

  %w(parameters cgi_data session_data context).each do |var|
    should "send a request if #{var} is present" do
      notice = build_notice(var.to_sym => { 'key' => 'value' })
      json = notice.to_json
      payload = JSON.parse(json)
      assert_not_nil payload['request']
    end
  end

  should "not ignore an exception not matching ignore filters" do
    notice = build_notice(:error_class       => 'ArgumentError',
                          :ignore            => ['Argument'],
                          :ignore_by_filters => [lambda { |notice| false }])
    assert !notice.ignore?
  end

  should "ignore an exception with a matching error class" do
    notice = build_notice(:error_class => 'ArgumentError',
                          :ignore      => [ArgumentError])
    assert notice.ignore?
  end

  should "ignore an exception with an equal error class name" do
    notice = build_notice(:error_class => 'ArgumentError',
                          :ignore      => ['ArgumentError'])
    assert notice.ignore?, "Expected ArgumentError to ignore ArgumentError"
  end

  should "ignore an exception matching error class name" do
    notice = build_notice(:error_class => 'ArgumentError',
                          :ignore      => [/Error$/])
    assert notice.ignore?, "Expected /Error$/ to ignore ArgumentError"
  end

  should "ignore an exception that inherits from ignored error class" do
    class ::FooError < ArgumentError ; end
    notice = build_notice(:exception => FooError.new('Oh noes!'),
                          :ignore      => [ArgumentError])
    assert notice.ignore?, "Expected ArgumentError to ignore FooError"
  end

  should "ignore an exception with a matching filter" do
    filter = lambda {|notice| notice.error_class == 'ArgumentError' }
    notice = build_notice(:error_class       => 'ArgumentError',
                          :ignore_by_filters => [filter])
    assert notice.ignore?
  end

  should "not raise without an ignore list" do
    notice = build_notice(:ignore => nil, :ignore_by_filters => nil)
    assert_nothing_raised do
      notice.ignore?
    end
  end

  ignored_error_classes = %w(
    ActiveRecord::RecordNotFound
    AbstractController::ActionNotFound
    ActionController::RoutingError
    ActionController::InvalidAuthenticityToken
    CGI::Session::CookieStore::TamperedWithCookie
    ActionController::UnknownAction
  )

  ignored_error_classes.each do |ignored_error_class|
    should "ignore #{ignored_error_class} error by default" do
      notice = build_notice(:error_class => ignored_error_class)
      assert notice.ignore?
    end
  end

  should "act like a hash" do
    notice = build_notice(:error_message => 'some message')
    assert_equal notice.error_message, notice[:error_message]
  end

  should "return params on notice[:request][:params]" do
    params = { 'one' => 'two' }
    notice = build_notice(:parameters => params)
    assert_equal params, notice[:request][:params]
  end

  should "return context on notice[:request][:context]" do
    context = { 'one' => 'two' }
    notice = build_notice(:context => context)
    assert_equal context, notice[:request][:context]
  end

  should "merge context from args with context from Honeybadger#context" do
    Honeybadger.context({ 'one' => 'two', 'foo' => 'bar' })
    notice = build_notice(:context => { 'three' => 'four', 'foo' => 'baz' })
    assert_equal({ 'one' => 'two', 'three' => 'four', 'foo' => 'baz' }, notice[:request][:context])
  end

  should "return nil context when context is not set" do
    notice = build_notice
    assert_equal nil, notice[:request][:context]
  end

  should "ensure #to_hash is called on objects that support it" do
    assert_nothing_raised do
      build_notice(:session => { :object => stub(:to_hash => {}) })
    end
  end

  should "ensure #to_ary is called on objects that support it" do
    assert_nothing_raised do
      build_notice(:session => { :object => stub(:to_ary => {}) })
    end
  end

  should "extract data from a rack environment hash" do
    url = "https://subdomain.happylane.com:100/test/file.rb?var=value&var2=value2"
    parameters = { 'var' => 'value', 'var2' => 'value2' }
    env = Rack::MockRequest.env_for(url)

    notice = build_notice(:rack_env => env)

    assert_equal url, notice.url
    assert_equal parameters, notice.parameters
    assert_equal 'GET', notice.cgi_data['REQUEST_METHOD']
  end

  should "extract data from a rack environment hash with action_dispatch info" do
    params = { 'controller' => 'users', 'action' => 'index', 'id' => '7' }
    env = Rack::MockRequest.env_for('/', { 'action_dispatch.request.parameters' => params })

    notice = build_notice(:rack_env => env)

    assert_equal params, notice.parameters
    assert_equal params['controller'], notice.component
    assert_equal params['action'], notice.action
  end

  should "extract session data from a rack environment" do
    session_data = { 'something' => 'some value' }
    env = Rack::MockRequest.env_for('/', 'rack.session' => session_data)

    notice = build_notice(:rack_env => env)

    assert_equal session_data, notice.session_data
  end

  should "prefer passed session data to rack session data" do
    session_data = { 'something' => 'some value' }
    env = Rack::MockRequest.env_for('/')

    notice = build_notice(:rack_env => env, :session_data => session_data)

    assert_equal session_data, notice.session_data
  end

  unless Gem::Version.new(Rack.release) < Gem::Version.new('1.2')
    should "fail gracefully when Rack params cannot be parsed" do
      rack_env = Rack::MockRequest.env_for('http://www.example.com/explode', :method => 'POST', :input => 'foo=bar&bar=baz%')
      notice = Honeybadger::Notice.new(:rack_env => rack_env)
      assert_equal 1, notice.params.size
      assert_match /Failed to call params on Rack::Request/, notice.params[:error]
    end
  end

  should "not send session data when send_request_session is false" do
    notice = build_notice(:send_request_session => false, :session_data => { :foo => :bar })
    assert_equal nil, notice.session_data
  end

  should "not allow infinite recursion" do
    hash = {:a => :a}
    hash[:hash] = hash
    notice = Honeybadger::Notice.new(:parameters => hash)
    assert_equal "[possible infinite recursion halted]", notice.parameters[:hash]
  end

  def assert_accepts_exception_attribute(attribute, args = {}, &block)
    exception = build_exception
    block ||= lambda { exception.send(attribute) }
    value = block.call(exception)

    notice_from_exception = build_notice(args.merge(:exception => exception))

    assert_equal notice_from_exception.send(attribute),
                 value,
                 "#{attribute} was not correctly set from an exception"

    notice_from_hash = build_notice(args.merge(attribute => value))
    assert_equal notice_from_hash.send(attribute),
                 value,
                 "#{attribute} was not correctly set from a hash"
  end

  def assert_serializes_hash(attribute)
    [File.open(__FILE__), Proc.new { puts "boo!" }, Module.new].each do |object|
      hash = {
        :strange_object => object,
        :sub_hash => {
          :sub_object => object
        },
        :array => [object]
      }
      notice = build_notice(attribute => hash)
      hash = notice.send(attribute)
      assert_equal object.to_s, hash[:strange_object], "objects should be serialized"
      assert_kind_of Hash, hash[:sub_hash], "subhashes should be kept"
      assert_equal object.to_s, hash[:sub_hash][:sub_object], "subhash members should be serialized"
      assert_kind_of Array, hash[:array], "arrays should be kept"
      assert_equal object.to_s, hash[:array].first, "array members should be serialized"
    end
  end

  def assert_filters_hash(attribute)
    filters  = ["abc", :def]
    original = { 'abc' => "123", 'def' => "456", 'ghi' => "789", 'nested' => { 'abc' => '100' },
      'something_with_abc' => 'match the entire string'}
    filtered = { 'abc'    => "[FILTERED]",
                 'def'    => "[FILTERED]",
                 'something_with_abc' => "match the entire string",
                 'ghi'    => "789",
                 'nested' => { 'abc' => '[FILTERED]' } }

    notice = build_notice(:params_filters => filters, attribute => original)

    assert_equal(filtered,
                 notice.send(attribute))
  end

  def build_backtrace_array
    ["app/models/user.rb:13:in `magic'",
      "app/controllers/users_controller.rb:8:in `index'"]
  end

  def hostname
    `hostname`.chomp
  end
end
