# encoding: utf-8

require 'honeybadger/notice'
require 'honeybadger/config'
require 'timecop'

describe Honeybadger::Notice do
  let(:config) { build_config }

  def build_config(opts = {})
    Honeybadger::Config.new({logger: NULL_LOGGER, api_key: 'asdf'}.merge(opts))
  end

  def build_notice(opts = {})
    config = opts[:config] || build_config
    Honeybadger::Notice.new(config, opts)
  end

  def assert_accepts_exception_attribute(attribute, args = {}, &block)
    exception = build_exception
    block ||= lambda { exception.send(attribute) }
    value = block.call(exception)

    notice_from_exception = build_notice(args.merge(exception: exception))

    expect(notice_from_exception.send(attribute)).to eq value

    notice_from_hash = build_notice(args.merge(attribute => value))
    expect(notice_from_hash.send(attribute)).to eq value
  end

  def build_backtrace_array
    ["app/models/user.rb:13:in `magic'",
      "app/controllers/users_controller.rb:8:in `index'"]
  end

  def assert_array_starts_with(expected, actual)
    expect(actual).to respond_to :to_ary
    array = actual.to_ary.reverse
    expected.reverse.each_with_index do |value, i|
      expect(array[i]).to eq value
    end
  end

  it "generates json from as_json template" do
    notice = build_notice
    hash = {'foo' => 'bar'}
    expect(notice).to receive(:as_json).once.and_return(hash)
    json = notice.to_json

    payload = nil
    expect { payload = JSON.parse(json) }.not_to raise_error

    expect(payload).to eq hash
  end

  it "accepts a component" do
    expect(build_notice(component: 'users_controller').controller).to eq 'users_controller'
  end

  it "aliases the component as controller" do
    expect(build_notice(controller: 'users_controller').component).to eq 'users_controller'
    expect(build_notice(controller: 'users_controller').controller).to eq 'users_controller'
  end

  it "aliases the params as parameters" do
    expect(build_notice(parameters: {foo: 'foo'}).params).to eq({foo: 'foo'})
    expect(build_notice(params: {bar: 'bar'}).parameters).to eq({bar: 'bar'})
  end

  it "accepts an action" do
    expect(build_notice(action: 'index').action).to eq 'index'
  end

  it "accepts a url" do
    url = 'http://some.host/uri'
    notice = build_notice(url: url)
    expect(notice.url).to eq url
  end

  it "sets the error class from an exception or hash" do
    assert_accepts_exception_attribute :error_class do |exception|
      exception.class.name
    end
  end

  it "sets the error message from an exception or hash" do
    assert_accepts_exception_attribute :error_message do |exception|
      "#{exception.class.name}: #{exception.message}"
    end
  end

  it "accepts parameters from a request or hash" do
    params = {'one' => 'two'}
    notice_from_hash = build_notice(params: params)
    expect(notice_from_hash.params).to eq params
  end

  it "accepts session data from a session[:data] hash" do
    data = {'one' => 'two'}
    notice = build_notice(session: {data: data})
    expect(notice.session).to eq data
  end

  it "accepts session data from a session hash" do
    data = {'one' => 'two'}
    notice = build_notice(session: data)
    expect(notice.session).to eq data
  end

  it "accepts CGI data from a hash" do
    data = {'STRING' => 'value'}
    notice = build_notice(cgi_data: data)
    expect(notice.cgi_data).to eq data
  end

  it "sets sensible defaults without an exception" do
    backtrace = Honeybadger::Backtrace.parse(build_backtrace_array)
    notice = build_notice(backtrace: build_backtrace_array)

    expect(notice.error_message).to eq 'Notification'
    assert_array_starts_with(backtrace.lines, notice.backtrace.lines)
    expect(notice.params).to be_empty
    expect(notice.session).to be_empty
  end

  it "uses the caller as the backtrace for an exception without a backtrace" do
    backtrace = Honeybadger::Backtrace.parse(caller, filters: Honeybadger::Notice::BACKTRACE_FILTERS)
    notice = build_notice(exception: StandardError.new('error'), backtrace: nil)

    assert_array_starts_with backtrace.lines, notice.backtrace.lines
  end

  it "does not send empty request data" do
    notice = build_notice
    expect(notice.url).to be_nil
    expect(notice.controller).to be_nil
    expect(notice.action).to be_nil

    json = notice.to_json
    payload = JSON.parse(json)
    expect(payload['request']['url']).to be_nil
    expect(payload['request']['component']).to be_nil
    expect(payload['request']['action']).to be_nil
  end

  it "does not filter the backtrace" do
    notice = build_notice(:config => build_config(:'request.filter_keys' => ['number']), :backtrace => ['foo:1:in `bar\''])
    json = notice.to_json
    payload = JSON.parse(json)
    expect(payload['error']['backtrace'][0]['number']).to eq '1'
  end

  %w(params session cgi_data).each do |var|
    it "does not filter top level #{var}" do
      notice = build_notice(:config => build_config(:'request.filter_keys' => [var]), var.to_sym => {var => 'hello'})
      json = notice.to_json
      payload = JSON.parse(json)
      expect(payload['request'][var]).to eq({var => '[FILTERED]'})
    end

    context "when #{var} is excluded" do
      it "sends default value" do
        cfg = var == 'cgi_data' ? 'environment' : var
        notice = build_notice(:config => build_config(:"request.disable_#{cfg}" => true), var.to_sym => {var => 'hello'})
        json = notice.to_json
        payload = JSON.parse(json)
        expect(payload['request'][var]).to eq({})
      end
    end
  end

  %w(url component action).each do |var|
    it "does not filter top level #{var}" do
      notice = build_notice(:config => build_config(:'request.filter_keys' => [var]), var.to_sym => 'hello')
      json = notice.to_json
      payload = JSON.parse(json)
      expect(payload['request'][var]).to eq 'hello'
    end
  end

  context "when url is excluded" do
    it "sends default value" do
      notice = build_notice(:config => build_config(:'request.disable_url' => true), :url => 'hello')
      json = notice.to_json
      payload = JSON.parse(json)
      expect(payload['request']['url']).to eq nil
    end
  end

  describe "#ignore?" do
    it "does not ignore an exception not matching ignore filters" do
      config = build_config(:'exceptions.ignore' => ['Argument'])
      config.exception_filter {|n| false }
      notice = build_notice(error_class: 'ArgumentError',
                            config: config,
                            callbacks: config)
      expect(notice.ignore?).to eq false
    end

    it "ignores an exception with a matching error class" do
      notice = build_notice(error_class: 'ArgumentError',
                            config: build_config(:'exceptions.ignore' => [ArgumentError]))
      expect(notice.ignore?).to eq true
    end

    it "ignores an exception with an equal error class name" do
      notice = build_notice(error_class: 'ArgumentError',
                            config: build_config(:'exceptions.ignore' => ['ArgumentError']))
      expect(notice.ignore?).to eq true # Expected ArgumentError to ignore ArgumentError
    end

    it "ignores an exception matching error class name" do
      notice = build_notice(error_class: 'ArgumentError',
                            config: build_config(:'exceptions.ignore' => [/Error$/]))
      expect(notice.ignore?).to eq true # Expected /Error$/ to ignore ArgumentError
    end

    it "ignores an exception that inherits from ignored error class" do
      class ::FooError < ArgumentError ; end
      notice = build_notice(exception: FooError.new('Oh noes!'),
                            config: build_config(:'exceptions.ignore' => [ArgumentError]))
      expect(notice.ignore?).to eq true # Expected ArgumentError to ignore FooError
    end

    it "ignores an exception with a matching filter" do
      config = build_config
      config.exception_filter {|n| n.error_class == 'ArgumentError' }
      notice = build_notice(error_class: 'ArgumentError',
                            config: config)
      expect(notice.ignore?).to eq true
    end

    it "does not raise without callbacks" do
      notice = build_notice(callbacks: nil)
      expect { notice.ignore? }.not_to raise_error
    end

    it "does not raise with default callbacks" do
      config = build_config
      notice = build_notice(callbacks: config)
      expect { notice.ignore? }.not_to raise_error
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
      it "ignores #{ignored_error_class} error by default" do
        notice = build_notice(error_class: ignored_error_class)
        expect(notice.ignore?).to eq true
      end
    end
  end

  describe "#[]" do
    it "acts like a hash" do
      notice = build_notice(error_message: 'some message')
      expect(notice[:error_message]).to eq notice.error_message
    end

    it "returns params on notice[:request][:params]" do
      params = {'one' => 'two'}
      notice = build_notice(params: params)
      expect(notice[:request][:params]).to eq params
    end

    it "returns context on notice[:request][:context]" do
      context = {'one' => 'two'}
      notice = build_notice(context: context)
      expect(notice[:request][:context]).to eq context
    end
  end

  describe "#context" do
    it "merges context from args with context from Honeybadger#context" do
      Thread.current[:__honeybadger_context] = {'one' => 'two', 'foo' => 'bar'}
      notice = build_notice(:context => {'three' => 'four', 'foo' => 'baz'})
      expect(notice[:request][:context]).to eq({'one' => 'two', 'three' => 'four', 'foo' => 'baz'})
    end

    it "doesn't mutate global context" do
      Thread.current[:__honeybadger_context] = {'one' => 'two'}
      expect { build_notice(:context => {'foo' => 'bar'}) }.not_to change { Thread.current[:__honeybadger_context] }
    end

    it "doesn't mutate local context" do
      Thread.current[:__honeybadger_context] = {'one' => 'two'}
      hash = {'foo' => 'bar'}
      expect { build_notice(:context => hash) }.not_to change { hash }
    end

    it "returns nil context when context is not set" do
      notice = build_notice
      expect(notice[:request][:context]).to be_nil
    end

    it "allows falsey values in context" do
      Thread.current[:__honeybadger_context] = {:debuga => true, :debugb => false}
      notice = build_notice
      hash = JSON.parse(notice.to_json)
      expect(hash['request']['context']).to eq({'debuga' => true, 'debugb' => false})
    end
  end

  describe "Rack features", if: defined?(::Rack) do
    context "with a rack environment hash" do
      it "extracts data from a rack environment hash" do
        url = "https://subdomain.happylane.com:100/test/file.rb?var=value&var2=value2"
        params = {'var' => 'value', 'var2' => 'value2'}
        env = Rack::MockRequest.env_for(url)
        notice = build_notice(rack_env: env)

        expect(notice.url).to eq url
        expect(notice.params).to eq params
        expect(notice.cgi_data['REQUEST_METHOD']).to eq 'GET'
      end

      it "prefers honeybadger.request.url to default PATH_INFO" do
        url = 'https://subdomain.happylane.com:100/test/file.rb?var=value&var2=value2'
        env = Rack::MockRequest.env_for(url)
        env['honeybadger.request.url'] = 'http://foo.com'
        notice = build_notice(rack_env: env)

        expect(notice.url).to eq 'http://foo.com'
      end

      context "with action_dispatch info" do
        let(:params) { {'controller' => 'users', 'action' => 'index', 'id' => '7'} }

        it "extracts data from a rack environment hash " do
          env = Rack::MockRequest.env_for('/', { 'action_dispatch.request.parameters' => params })
          notice = build_notice(rack_env: env)

          expect(notice.params).to eq params
          expect(notice.component).to eq params['controller']
          expect(notice.action).to eq params['action']
        end

        it "removes action_dispatch.request.parameters from cgi_data" do
          env = Rack::MockRequest.env_for('/', { 'action_dispatch.request.parameters' => params })
          notice = build_notice(rack_env: env)

          expect(notice[:cgi_data]).not_to have_key 'action_dispatch.request.parameters'
        end

        it "removes action_dispatch.request.request_parameters from cgi_data" do
          env = Rack::MockRequest.env_for('/', { 'action_dispatch.request.request_parameters' => params })
          notice = build_notice(rack_env: env)

          expect(notice[:cgi_data]).not_to have_key 'action_dispatch.request.request_parameters'
        end
      end

      it "extracts session data from a rack environment" do
        session = { 'something' => 'some value' }
        env = Rack::MockRequest.env_for('/', 'rack.session' => session)
        notice = build_notice(rack_env: env)

        expect(notice.session).to eq session
      end

      it "prefers passed session data to rack session data" do
        session = { 'something' => 'some value' }
        env = Rack::MockRequest.env_for('/')
        notice = build_notice(rack_env: env, session: session)

        expect(notice.session).to eq session
      end

      if defined?(::Rack) && Gem::Version.new(Rack.release) < Gem::Version.new('1.3')
        it "parses params which are malformed in Rack >= 1.3" do
          env = Rack::MockRequest.env_for('http://www.example.com/explode', :method => 'POST', :input => 'foo=bar&bar=baz%')
          expect {
            build_notice(rack_env: env)
          }.not_to raise_error
        end
      else
        it "fails gracefully when Rack params cannot be parsed" do
          env = Rack::MockRequest.env_for('http://www.example.com/explode', :method => 'POST', :input => 'foo=bar&bar=baz%')
          notice = build_notice(rack_env: env)
          expect(notice.params.size).to eq 1
          expect(notice.params[:error]).to match(/Failed to access params/)
        end
      end
    end
  end

  it "prefers notice args to exception attributes" do
    e = RuntimeError.new('Not very helpful')
    notice = build_notice(exception: e, error_class: 'MyClass', error_message: 'Something very specific went wrong.')
    expect(notice.error_class).to eq 'MyClass'
    expect(notice.error_message).to eq 'Something very specific went wrong.'
  end

  describe "config[:'exceptions.unwrap']" do
    class TheCause < RuntimeError; end

    let(:notice) { build_notice(exception: exception, config: config) }
    let(:exception) { RuntimeError.new('foo') }

    context "when there isn't a cause" do
      context "and disabled (default)" do
        it "reports the exception" do
          expect(notice.error_class).to eq 'RuntimeError'
        end
      end

      context "and enabled" do
        let(:config) { build_config(:'exceptions.unwrap' => true) }

        it "reports the exception" do
          expect(notice.error_class).to eq 'RuntimeError'
        end
      end
    end

    context "when there is a cause" do
      before do
        def exception.cause
          TheCause.new(':trollface:')
        end
      end

      context "and disabled (default)" do
        it "reports the exception" do
          expect(notice.error_class).to eq 'RuntimeError'
        end
      end

      context "and enabled" do
        let(:config) { build_config(:'exceptions.unwrap' => true) }

        it "reports the cause" do
          expect(notice.error_class).to eq 'TheCause'
          expect(notice.error_message).to match /trollface/
        end
      end
    end
  end

  describe "#as_json" do
    it "sets the host name" do
      notice = build_notice(config: build_config(hostname: 'foo'))
      expect(notice.as_json[:server][:hostname]).to eq 'foo'
    end

    it "sets the environment name" do
      notice = build_notice(config: build_config(env: 'foo'))
      expect(notice.as_json[:server][:environment_name]).to eq 'foo'
    end

    it "defaults api key to configuration" do
      notice = build_notice
      expect(notice.as_json[:api_key]).to eq 'asdf'
    end

    it "overrides the api key" do
      notice = build_notice({api_key: 'zxcv'})
      expect(notice.as_json[:api_key]).to eq 'zxcv'
    end

    it "sets the time in utc" do
      allow(Time).to receive(:now).and_return(now = Time.now)
      notice = build_notice
      expect(notice.as_json[:server][:time]).to eq now.utc
    end

    it "sets the process id" do
      notice = build_notice
      expect(notice.as_json[:server][:pid]).to eq Process.pid
    end

    it "converts the backtrace to an array" do
      notice = build_notice
      expect(notice.as_json[:error][:backtrace]).to be_a Array
      expect(notice.as_json[:error][:backtrace]).to eq notice.backtrace.to_ary
    end

    it "trims error message to 2k" do
      message = 'asdfghjkl'*400
      e = StandardError.new(message)
      notice = build_notice(exception: e)
      expect(message.bytesize).to be > 2048
      expect(2048...2068).to cover notice.as_json[:error][:message].bytesize
    end
  end

  context "custom fingerprint" do
    it "includes nil fingerprint when no fingerprint is specified" do
      notice = build_notice
      expect(notice.fingerprint).to be_nil
    end

    it "accepts fingerprint as string" do
      notice = build_notice({fingerprint: 'foo' })
      expect(notice.fingerprint).to eq '0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33'
    end

    it "accepts fingerprint responding to #call" do
      notice = build_notice({fingerprint: double(call: 'foo')})
      expect(notice.fingerprint).to eq '0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33'
    end

    it "accepts fingerprint using #to_s" do
      notice = build_notice({fingerprint: double(to_s: 'foo')})
      expect(notice.fingerprint).to eq '0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33'
    end

    context "fingerprint is a callback which accesses notice" do
      it "can access request information" do
        notice = build_notice({params: { key: 'foo' }, fingerprint: lambda {|n| n[:params][:key] }})
        expect(notice.fingerprint).to eq '0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33'
      end
    end
  end

  context "with a backtrace" do
    before(:each) do
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

    it "passes its backtrace filters for parsing" do
      allow(config).to receive(:backtrace_filter).and_return('foo')
      expect(Honeybadger::Backtrace).to receive(:parse).with(@backtrace_array, hash_including(filters: array_including('foo'))).and_return(double(lines: []))
      build_notice({exception: @exception, config: config})
    end

    it "passes backtrace line filters for parsing" do
      allow(config).to receive(:backtrace_filter).and_return('foo')

      @backtrace_array.each do |line|
        expect(Honeybadger::Backtrace::Line).to receive(:parse).with(line, hash_including({filters: array_including('foo'), config: config}))
      end

      build_notice({exception: @exception, callbacks: config, config: config})
    end

    it "accepts a backtrace from an exception or hash" do
      backtrace = Honeybadger::Backtrace.parse(@backtrace_array)
      notice_from_exception = build_notice(exception: @exception)

      expect(notice_from_exception.backtrace).to eq backtrace # backtrace was not correctly set from an exception

      notice_from_hash = build_notice(backtrace: @backtrace_array)
      expect(notice_from_hash.backtrace).to eq backtrace # backtrace was not correctly set from a hash
    end
  end

  describe "#to_json" do
    context "when bad encodings exist in payload" do
      let(:bad_string) { 'hello ümlaut'.force_encoding('BINARY') }
      let(:invalid) { (100..1000).to_a.pack('c*').force_encoding('utf-8') }

      it "doesn't blow up with bad encoding" do
        notice = build_notice(error_message: bad_string)
        expect { notice.to_json }.not_to raise_error
      end

      it "doesn't blow up with invalid encoding" do
        notice = build_notice(error_message: invalid)
        expect { notice.to_json }.not_to raise_error
      end

      it "converts to utf-8" do
        notice = build_notice(error_message: bad_string)
        expect(JSON.parse(notice.to_json)['error']['message']).to eq 'hello ??mlaut'
      end
    end

    it "includes source extracts in backtrace" do
      notice = build_notice
      json = JSON.parse(notice.to_json)

      json['error']['backtrace'].each do |line|
        expect(line['source']).not_to be_empty
      end
    end
  end

  context "adding tags" do
    context "directly" do
      it "converts String to tags Array" do
        expect(build_notice(tags: ' foo  , bar, ,  $baz   ').tags).to eq(%w(foo bar baz))
      end

      it "accepts an Array" do
        expect(build_notice(tags: [' foo  ', ' bar', ' ', '  $baz   ']).tags).to eq(%w(foo bar baz))
      end
    end

    context "from context" do
      it "converts String to tags Array" do
        expect(build_notice(context: { tags: ' foo  , , bar,  $baz   ' }).tags).to eq(%w(foo bar baz))
      end

      it "accepts an Array" do
        expect(build_notice(tags: [' foo  ', ' bar', ' ', '  $baz   ']).tags).to eq(%w(foo bar baz))
      end
    end

    context "from both" do
      it "merges tags" do
        expect(build_notice(tags: 'baz', context: { tags: ' foo  , bar ' }).tags).to eq(%w(foo bar baz))
      end
    end
  end

  context "exception cause" do
    class CauseError < StandardError
      attr_reader :cause
      def cause=(e); @cause = e; end
    end

    class OriginalExceptionError < StandardError
      attr_reader :original_exception
      def cause=(e); @original_exception = e; end
    end

    class ContinuedExceptionError < StandardError
      attr_reader :continued_exception
      def cause=(e); @continued_exception = e; end
    end

    [CauseError, OriginalExceptionError, ContinuedExceptionError].each do |error_class|
      context "when raising #{error_class} without a cause" do
        it "includes empty cause in payload" do
          exception = error_class.new('badgers!')
          causes = build_notice(exception: exception).as_json[:error][:causes]
          expect(causes.size).to eq 0
        end
      end

      context "when raising #{error_class} with a cause" do
        it "includes the cause in the payload" do
          exception = error_class.new('badgers!')
          exception.cause = StandardError.new('cause!')
          causes = build_notice(exception: exception).as_json[:error][:causes]
          expect(causes.size).to eq 1
          expect(causes[0][:class]).to eq 'StandardError'
          expect(causes[0][:message]).to eq 'cause!'
          expect(causes[0][:backtrace]).not_to be_empty
        end

        it "stops unwrapping at 5" do
          exception = e = error_class.new('badgers!')

          0.upto(6) do
            e.cause = c = error_class.new('cause!')
            e = c
          end

          causes = build_notice(exception: exception).as_json[:error][:causes]
          expect(causes.size).to eq 5
        end
      end

      context "when raising #{error_class} with a non-exception cause" do
        it "includes empty cause in payload" do
          exception = error_class.new('badgers!')
          exception.cause = "Some reason you werent expecting"
          causes = build_notice(exception: exception).as_json[:error][:causes]
          expect(causes.size).to eq 0
        end
      end
    end
  end
end
