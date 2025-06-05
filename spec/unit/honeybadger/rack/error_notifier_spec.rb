require "honeybadger/rack/error_notifier"

class BacktracedException < RuntimeError
  attr_accessor :backtrace
  def initialize(opts)
    @backtrace = opts[:backtrace]
  end

  def set_backtrace(bt)
    @backtrace = bt
  end
end

def build_exception(opts = {})
  backtrace = ["test/honeybadger/rack_test.rb:15:in `build_exception'",
    "test/honeybadger/rack_test.rb:52:in `test_delivers_exception_from_rack'",
    "/Users/josh/Developer/.rvm/gems/ruby-1.9.3-p0/gems/mocha-0.10.5/lib/mocha/integration/mini_test/version_230_to_262.rb:28:in `run'"]
  opts = {backtrace: backtrace}.merge(opts)
  BacktracedException.new(opts)
end

describe Honeybadger::Rack::ErrorNotifier do
  let(:agent) { Honeybadger::Agent.new }
  let(:config) { agent.config }

  it "calls the upstream app with the environment" do
    environment = {"key" => "value"}
    app = lambda { |env| ["response", {}, env] }
    stack = Honeybadger::Rack::ErrorNotifier.new(app, agent)

    response = stack.call(environment)

    expect(response).to eq ["response", {}, environment]
  end

  it "delivers an exception raised while calling an upstream app" do
    allow(agent).to receive(:notify)

    exception = build_exception
    environment = {"key" => "value"}
    app = lambda do |env|
      raise exception
    end

    expect(agent).to receive(:notify).with(exception)

    begin
      stack = Honeybadger::Rack::ErrorNotifier.new(app, agent)
      stack.call(environment)
    rescue StandardError => raised
      expect(raised).to eq exception
    else
      fail "Didn't raise an exception"
    end
  end

  it "delivers an exception in rack.exception" do
    allow(agent).to receive(:notify)
    exception = build_exception
    environment = {"key" => "value"}

    response = [200, {}, ["okay"]]
    app = lambda do |env|
      env["rack.exception"] = exception
      response
    end
    stack = Honeybadger::Rack::ErrorNotifier.new(app, agent)

    expect(agent).to receive(:notify).with(exception)

    actual_response = stack.call(environment)

    expect(actual_response).to eq response
  end

  it "delivers an exception in sinatra.error" do
    allow(agent).to receive(:notify)
    exception = build_exception
    environment = {"key" => "value"}

    response = [200, {}, ["okay"]]
    app = lambda do |env|
      env["sinatra.error"] = exception
      response
    end
    stack = Honeybadger::Rack::ErrorNotifier.new(app, agent)

    expect(agent).to receive(:notify).with(exception)

    actual_response = stack.call(environment)

    expect(actual_response).to eq response
  end

  it "clears context after app is called" do
    Honeybadger.context(foo: :bar)
    expect(Honeybadger.get_context).to eq({foo: :bar})

    app = lambda { |env| ["response", {}, env] }
    stack = Honeybadger::Rack::ErrorNotifier.new(app, agent)

    stack.call({})

    expect(Honeybadger.get_context).to be_nil
  end
end
