require "honeybadger/plugins/rails"

begin
  require "rack/request"
rescue LoadError
  return
end

describe Honeybadger::Plugins::Rails::ErrorSubscriber do
  it "excludes the controller from handled errors while preserving user context" do
    exception = StandardError.new("handled error")
    context = {controller: Object.new, user_id: 123}

    expect(Honeybadger).to receive(:notify).with(exception,
      context: {user_id: 123}, tags: ["severity:warning", "handled:true", "source:application"])

    described_class.report(exception, handled: true, severity: :warning,
      context: context, source: "application")

    expect(context).to have_key(:controller)
  end
end

describe "Rails execution context integration" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }
  let(:execution_context) { double("ExecutionContext") }
  let(:context) { {controller: Object.new, user_id: 123} }

  before do
    Honeybadger::Plugin.instances[:rails_exceptions_catcher].reset!
    stub_const("Rails", Module.new)
    allow(Rails).to receive(:application).and_return(double("application"))
    allow(Rails).to receive(:error).and_return(double("ErrorReporter", subscribe: nil))
    stub_const("ActiveSupport::ErrorReporter", Class.new)
    stub_const("ActiveSupport::ExecutionContext", execution_context)
    allow(execution_context).to receive(:to_h).and_return(context)
    allow(execution_context).to receive(:after_change) { |&callback| @after_change = callback }
    allow(Honeybadger).to receive(:config).and_return(config)
    Honeybadger::Plugin.instances[:rails_exceptions_catcher].load!(config)
  end

  it "excludes the controller instance while preserving user context" do
    @after_change.call

    expect(Honeybadger.get_context).to eq(user_id: 123)
    expect(context).to have_key(:controller)
  end

  it "copies user context when there is no controller" do
    context.delete(:controller)
    @after_change.call

    expect(Honeybadger.get_context).to eq(user_id: 123)
  end
end
