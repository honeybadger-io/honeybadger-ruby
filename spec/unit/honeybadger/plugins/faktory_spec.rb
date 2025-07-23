require "honeybadger/plugins/faktory"
require "honeybadger/config"

describe "Faktory Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:faktory].reset!
  end

  context "when faktory is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:faktory].load!(config) }.not_to raise_error
    end
  end

  context "when faktory is installed" do
    let(:shim) do
      Class.new do
        def self.configure_worker
        end
      end
    end

    let(:faktory_config) { double("config", error_handlers: []) }
    let(:chain) { double("chain", prepend: true) }

    before do
      Object.const_set(:Faktory, shim)
      allow(::Faktory).to receive(:configure_worker).and_yield(faktory_config)
      allow(faktory_config).to receive(:worker_middleware).and_yield(chain)
    end

    after { Object.send(:remove_const, :Faktory) }

    it "adds the error handler" do
      Honeybadger::Plugin.instances[:faktory].load!(config)
      expect(faktory_config.error_handlers).not_to be_empty
    end

    describe "error handler" do
      let(:exception) { RuntimeError.new("boom") }

      before do
        Honeybadger::Plugin.instances[:faktory].load!(config)
      end

      context "not within job execution" do
        let(:handler_context) { {context: "Failed Hard", event: {}} }

        it "notifies Honeybadger" do
          expect(Honeybadger).to receive(:notify).with(exception, parameters: handler_context).once
          faktory_config.error_handlers[0].call(exception, handler_context)
        end
      end

      context "within job execution" do
        let(:handler_context) { {context: "Job raised exception", job: job} }
        let(:job) { first_invocation }
        let(:retried_invocation) { {"retry" => retry_limit, "failure" => failure, "jobtype" => "JobType"} }
        let(:first_invocation) { {"retry" => retry_limit, "jobtype" => "JobType"} }
        let(:failure) { {"retry_count" => attempt - 1} }
        let(:retry_limit) { 5 }
        let(:attempt) { 0 }

        let(:error_payload) {
          {
            parameters: handler_context,
            component: "JobType",
            action: "perform"
          }
        }

        it "notifies Honeybadger" do
          expect(Honeybadger).to receive(:notify).with(exception, **error_payload).once
          faktory_config.error_handlers[0].call(exception, handler_context)
        end

        context "when an attempt threshold is configured" do
          let(:job) { retried_invocation }
          let(:retry_limit) { 1 }
          let(:attempt) { 0 }
          let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "faktory.attempt_threshold": 5) }

          it "doesn't notify Honeybadger" do
            expect(Honeybadger).not_to receive(:notify)
            faktory_config.error_handlers[0].call(exception, handler_context)
          end

          context "and the retry_limit is zero on first invocation" do
            let(:job) { first_invocation }
            let(:retry_limit) { 0 }

            it "notifies Honeybadger" do
              expect(Honeybadger).to receive(:notify).with(exception, **error_payload).once
              faktory_config.error_handlers[0].call(exception, handler_context)
            end
          end

          context "and the retry_limit is exhausted" do
            let(:attempt) { 3 }
            let(:retry_limit) { 3 }

            it "notifies Honeybadger" do
              expect(Honeybadger).to receive(:notify).with(exception, **error_payload).once
              faktory_config.error_handlers[0].call(exception, handler_context)
            end
          end

          context "and the attempts meets the threshold" do
            let(:attempt) { 5 }
            let(:retry_limit) { 10 }

            it "notifies Honeybadger" do
              expect(Honeybadger).to receive(:notify).with(exception, **error_payload).once
              faktory_config.error_handlers[0].call(exception, handler_context)
            end
          end
        end
      end
    end
  end
end
