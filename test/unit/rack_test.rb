require 'test_helper'

class RackTest < Test::Unit::TestCase
  should "call the upstream app with the environment" do
    environment = { 'key' => 'value' }
    app = lambda { |env| ['response', {}, env] }
    stack = Honeybadger::Rack.new(app)

    response = stack.call(environment)

    assert_equal ['response', {}, environment], response
  end

  should "deliver an exception raised while calling an upstream app" do
    Honeybadger.stubs(:notify_or_ignore)

    exception = build_exception
    environment = { 'key' => 'value' }
    app = lambda do |env|
      raise exception
    end

    begin
      stack = Honeybadger::Rack.new(app)
      stack.call(environment)
    rescue Exception => raised
      assert_equal exception, raised
    else
      flunk "Didn't raise an exception"
    end

    assert_received(Honeybadger, :notify_or_ignore) do |expect|
      expect.with(exception, :rack_env => environment)
    end
  end

  should "deliver an exception in rack.exception" do
    Honeybadger.stubs(:notify_or_ignore)
    exception = build_exception
    environment = { 'key' => 'value' }

    response = [200, {}, ['okay']]
    app = lambda do |env|
      env['rack.exception'] = exception
      response
    end
    stack = Honeybadger::Rack.new(app)

    actual_response = stack.call(environment)

    assert_equal response, actual_response
    assert_received(Honeybadger, :notify_or_ignore) do |expect|
      expect.with(exception, :rack_env => environment)
    end
  end

  should "deliver an exception in sinatra.error" do
    Honeybadger.stubs(:notify_or_ignore)
    exception = build_exception
    environment = { 'key' => 'value' }

    response = [200, {}, ['okay']]
    app = lambda do |env|
      env['sinatra.error'] = exception
      response
    end
    stack = Honeybadger::Rack.new(app)

    actual_response = stack.call(environment)

    assert_equal response, actual_response
    assert_received(Honeybadger, :notify_or_ignore) do |expect|
      expect.with(exception, :rack_env => environment)
    end
  end

  should "clear context after app is called" do
    Honeybadger.context( :foo => :bar )
    assert_equal({ :foo => :bar }, Thread.current[:honeybadger_context])

    app = lambda { |env| ['response', {}, env] }
    stack = Honeybadger::Rack.new(app)

    response = stack.call({})

    assert_equal nil, Thread.current[:honeybadger_context]
  end
end
