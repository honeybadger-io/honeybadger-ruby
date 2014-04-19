require 'spec_helper'
require 'rack'

describe Honeybadger::Rack::ErrorNotifier do
  it "calls the upstream app with the environment" do
    environment = { 'key' => 'value' }
    app = lambda { |env| ['response', {}, env] }
    stack = Honeybadger::Rack::ErrorNotifier.new(app)

    response = stack.call(environment)

    expect(response).to eq ['response', {}, environment]
  end

  it "delivers an exception raised while calling an upstream app" do
    Honeybadger.stub(:notify_or_ignore)

    exception = build_exception
    environment = { 'key' => 'value' }
    app = lambda do |env|
      raise exception
    end

    Honeybadger.should_receive(:notify_or_ignore).with(exception, :rack_env => environment)

    begin
      stack = Honeybadger::Rack::ErrorNotifier.new(app)
      stack.call(environment)
    rescue Exception => raised
      expect(raised).to eq exception
    else
      fail "Didn't raise an exception"
    end
  end

  it "delivers an exception in rack.exception" do
    Honeybadger.stub(:notify_or_ignore)
    exception = build_exception
    environment = { 'key' => 'value' }

    response = [200, {}, ['okay']]
    app = lambda do |env|
      env['rack.exception'] = exception
      response
    end
    stack = Honeybadger::Rack::ErrorNotifier.new(app)

    Honeybadger.should_receive(:notify_or_ignore).with(exception, :rack_env => environment)

    actual_response = stack.call(environment)

    expect(actual_response).to eq response
  end

  it "delivers an exception in sinatra.error" do
    Honeybadger.stub(:notify_or_ignore)
    exception = build_exception
    environment = { 'key' => 'value' }

    response = [200, {}, ['okay']]
    app = lambda do |env|
      env['sinatra.error'] = exception
      response
    end
    stack = Honeybadger::Rack::ErrorNotifier.new(app)

    Honeybadger.should_receive(:notify_or_ignore).with(exception, :rack_env => environment)

    actual_response = stack.call(environment)

    expect(actual_response).to eq response
  end

  it "clears context after app is called" do
    Honeybadger.context( :foo => :bar )
    expect(Thread.current[:honeybadger_context]).to eq({ :foo => :bar })

    app = lambda { |env| ['response', {}, env] }
    stack = Honeybadger::Rack::ErrorNotifier.new(app)

    stack.call({})

    expect(Thread.current[:honeybadger_context]).to be_nil
  end
end
