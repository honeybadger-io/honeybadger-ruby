require 'honeybadger/plugins/shoryuken'

class TestShoryukenWorker < Honeybadger::Plugins::Shoryuken::Middleware
end

describe "Shoryuken Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:shoryuken].reset!
  end

  context "when shoryuken is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:shoryuken].load!(config) }.not_to raise_error
    end
  end

  context "when shoryuken is installed" do
    let(:shim) do
      Class.new do
        def self.configure_server
        end
      end
    end

    let(:shoryuken_config) { double("config", {}) }
    let(:chain) { double("chain", :add => true) }

    before do
      Object.const_set(:Shoryuken, shim)
      allow(::Shoryuken).to receive(:configure_server).and_yield(shoryuken_config)
      allow(shoryuken_config).to receive(:server_middleware).and_yield(chain)
    end

    after { Object.send(:remove_const, :Shoryuken) }

    it "adds the server middleware" do
      expect(chain).to receive(:add).with(Honeybadger::Plugins::Shoryuken::Middleware)
      Honeybadger::Plugin.instances[:shoryuken].load!(config)
    end
  end
end

describe TestShoryukenWorker do
  let(:sqs_msg) do
    double("SqsMsg", queue_name: "queue", attributes: { "ApproximateReceiveCount" => receive_count }, data: double("SqsMsgData", message_id: rand.to_s))
  end

  shared_examples_for "notifies Honeybadger" do
    it "" do
      expect(Honeybadger).to receive(:notify).with(kind_of(RuntimeError), hash_including(parameters: [1, 2, 3]))
      expect { job_execution }.to raise_error(RuntimeError)
    end
  end

  shared_examples_for "doesn't notify Honeybadger" do
    it "" do
      expect(Honeybadger).to_not receive(:notify)
      expect { job_execution }.to raise_error(RuntimeError)
    end
  end

  let(:receive_count) { "1" }
  let(:sqs_msgs) { sqs_msg }
  let(:instance) { described_class.new }
  let(:job_execution) do
    instance.call(instance, nil, sqs_msgs, [1, 2, 3]) { fail "foo" }
  end

  context "with a single message" do
    context "when an attempt threshold is not configured" do
      include_examples "notifies Honeybadger"
    end

    context "when an attempt threshold is configured" do
      before { ::Honeybadger::Agent.config[:'shoryuken.attempt_threshold'] = 2 }
      after { ::Honeybadger::Agent.config[:'shoryuken.attempt_threshold'] = 0 }

      include_examples "doesn't notify Honeybadger"

      context "when retries are exhausted" do
        let(:receive_count) { "2" }
        include_examples "notifies Honeybadger"
      end
    end
  end

  context "with several messages" do
    let(:sqs_msgs) { 2.times.map { sqs_msg.dup } }
    include_examples "doesn't notify Honeybadger"
  end
end
