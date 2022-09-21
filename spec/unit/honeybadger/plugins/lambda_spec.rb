require 'honeybadger/plugins/lambda'
require 'honeybadger/config'

describe "Lambda Plugin" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, backend: :test, api_key: "noop") }

  before do
    expect(Honeybadger::Util::Lambda).to receive(:lambda_execution?).and_return(true)
  end

  after do
    Honeybadger::Plugin.instances[:lambda].reset!
    Honeybadger::Backend::Test.notifications[:notices].clear
  end

  it 'forces sync mode' do
    expect(config[:sync]).to eq false
    Honeybadger::Plugin.instances[:lambda].load!(config)
    expect(config[:sync]).to eq true
  end

  describe "hb_wrap_handler decorator" do
    it 'auto-captures errors from class methods when decorator is used' do
      expect(Honeybadger).to receive(:notify).with kind_of(RuntimeError)
      Honeybadger::Plugin.instances[:lambda].load!(config)

      klass = Class.new do
        extend ::Honeybadger::Plugins::LambdaExtension

        def self.test_handler(event:, context:)
          raise "An exception"
        end
        hb_wrap_handler :test_handler
      end

      expect { klass.test_handler(event: {}, context: {}) }.to raise_error(RuntimeError, "An exception")
    end

    it 'auto-captures errors from main methods when decorator is used' do
      expect(Honeybadger).to receive(:notify).with kind_of(RuntimeError)
      Honeybadger::Plugin.instances[:lambda].load!(config)

      main = TOPLEVEL_BINDING.eval("self")
      main.instance_eval do
        def test_handler(event:, context:)
          raise "An exception"
        end
        hb_wrap_handler :test_handler
      end

      expect { main.test_handler(event: {}, context: {}) }.to raise_error(RuntimeError, "An exception")
    end
  end

  describe "notice injection" do
    let(:lambda_data) { {
      "function" => "lambda_fn",
      "handler" => "the.handler",
      "memory" => 128
    } }

    before do
      expect(Honeybadger::Util::Lambda).to receive(:trace_id).and_return("abc123")
      expect(Honeybadger::Util::Lambda).to receive(:normalized_data).and_return(lambda_data)
    end

    it 'adds details to notice data and includes trace_id into context' do
      agent = Honeybadger::Agent.new(config)
      Honeybadger::Plugin.instances[:lambda].load!(config)
      agent.notify("test")
      notice = agent.backend.notifications[:notices].first
      expect(notice.component).to eq "lambda_fn"
      expect(notice.action).to eq "the.handler"
      expect(notice.context[:lambda_trace_id]).to eq "abc123"
      expect(notice.details).to eq({ "Lambda Details" => lambda_data })
    end
  end
end
