require "honeybadger/plugins/shoryuken"
require "honeybadger/config"

RSpec.describe "Shoryuken Dependency" do
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
    let(:chain) { double("chain", add: true) }

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

class TestShoryukenWorker < Honeybadger::Plugins::Shoryuken::Middleware; end

RSpec.describe TestShoryukenWorker do
  let(:sqs_msg) do
    double("SqsMsg",
      queue_name: "queue",
      attributes: {"ApproximateReceiveCount" => receive_count},
      data: double("SqsMsgData", message_id: rand.to_s))
  end
  let(:body) { {"key" => "value"} }

  shared_examples_for "notifies Honeybadger" do
    it do
      expect(Honeybadger).to receive(:notify).with(kind_of(RuntimeError),
        hash_including(parameters: {body: {"key" => "value"}}))

      expect { job_execution }.to raise_error(RuntimeError)
    end
  end

  shared_examples_for "batch notifies Honeybadger" do
    it do
      expect(Honeybadger).to receive(:notify).with(kind_of(RuntimeError),
        hash_including(parameters:
                         {batch: [
                           {"key" => "value"},
                           {"key" => "value"}
                         ]}))

      expect { job_execution }.to raise_error(RuntimeError)
    end
  end

  shared_examples_for "doesn't notify Honeybadger" do
    it do
      expect(Honeybadger).to_not receive(:notify)
      expect { job_execution }.to raise_error(RuntimeError)
    end
  end

  let(:receive_count) { "1" }
  let(:sqs_msgs) { sqs_msg }
  let(:bodies) { body }
  let(:instance) { described_class.new }
  let(:job_execution) do
    instance.call(instance, nil, sqs_msgs, bodies) { raise "foo" }
  end

  context "with a single message" do
    context "when an attempt threshold is not configured" do
      include_examples "notifies Honeybadger"
    end

    context "when an attempt threshold is configured" do
      before { ::Honeybadger.config[:"shoryuken.attempt_threshold"] = 2 }
      after { ::Honeybadger.config[:"shoryuken.attempt_threshold"] = 0 }

      include_examples "doesn't notify Honeybadger"

      context "when retries are exhausted" do
        let(:receive_count) { "2" }
        include_examples "notifies Honeybadger"
      end
    end
  end

  context "with several messages" do
    let(:sqs_msgs) { Array.new(2) { sqs_msg.dup } }
    let(:bodies) { Array.new(2) { body.dup } }

    include_examples "batch notifies Honeybadger"
  end
end
