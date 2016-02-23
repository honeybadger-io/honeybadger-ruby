require 'honeybadger/plugins/resque'
require 'honeybadger/config'
require 'honeybadger/agent'

class TestWorker
  extend Honeybadger::Plugins::Resque::Extension
end

describe TestWorker do
  shared_examples_for "clears the context" do
    it "" do
      expect {
        described_class.around_perform_with_honeybadger do
          Honeybadger.context(badgers: true)
        end
      }.not_to change { Thread.current[:__honeybadger_context] }.from(nil)
    end
  end

  shared_examples_for "reports exceptions" do
    it "" do
      expect(Honeybadger).to receive(:notify).with(kind_of(RuntimeError), hash_including(parameters: {job_arguments: [1, 2, 3]}))
      expect {
        described_class.around_perform_with_honeybadger(1, 2, 3) do
          fail 'foo'
        end
      }.to raise_error(RuntimeError)
    end
  end

  shared_examples_for "does not report exceptions" do
    it "" do
      expect(Honeybadger).not_to receive(:notify).with(kind_of(RuntimeError), hash_including(parameters: {job_arguments: [1, 2, 3]}))
      expect {
        described_class.around_perform_with_honeybadger(1, 2, 3) do
          fail 'foo'
        end
      }.to raise_error(RuntimeError)
    end
  end

  shared_examples_for "raises exceptions" do
    it "" do
      expect {
        described_class.around_perform_with_honeybadger do
          fail 'foo'
        end
      }.to raise_error(RuntimeError)
    end
  end

  describe "::around_perform_with_honeybadger" do
    describe "with worker not extending Resque::Plugins::Retry" do
      context "when send exceptions on retry enabled" do
        before { ::Honeybadger::Agent.config[:'resque.resque_retry.send_exceptions_when_retrying'] = true }
        it_behaves_like "clears the context"
        it_behaves_like "reports exceptions"
        it_behaves_like "raises exceptions"
      end

      context "when send exceptions on retry disabled" do
        before { ::Honeybadger::Agent.config[:'resque.resque_retry.send_exceptions_when_retrying'] = false }
        it_behaves_like "clears the context"
        it_behaves_like "reports exceptions"
        it_behaves_like "raises exceptions"
      end
    end

    describe "with worker extending Resque::Plugins::Retry" do
      let(:retry_criteria_valid) { false }
      before do
        class TestWorker
          extend Honeybadger::Plugins::Resque::Extension
          def self.retry_criteria_valid?(e)
          end
        end
        allow(described_class).to receive(:retry_criteria_valid?).
          and_return(retry_criteria_valid)
      end

      context "when send exceptions on retry enabled" do
        before { ::Honeybadger::Agent.config[:'resque.resque_retry.send_exceptions_when_retrying'] = true }

        context "with retry criteria invalid" do
          it_behaves_like "clears the context"
          it_behaves_like "reports exceptions"
          it_behaves_like "raises exceptions"
        end

        context "with retry criteria valid" do
          let(:retry_criteria_valid) { true }
          it_behaves_like "clears the context"
          it_behaves_like "reports exceptions"
          it_behaves_like "raises exceptions"
        end
      end

      context "when send exceptions on retry disabled" do
        before { ::Honeybadger::Agent.config[:'resque.resque_retry.send_exceptions_when_retrying'] = false }

        context "with retry criteria invalid" do
          it_behaves_like "clears the context"
          it_behaves_like "reports exceptions"
          it_behaves_like "raises exceptions"
        end

        context "with retry criteria valid" do
          let(:retry_criteria_valid) { true }
          it_behaves_like "clears the context"
          it_behaves_like "does not report exceptions"
          it_behaves_like "raises exceptions"
        end

        context "and retry_criteria_valid? raises exception" do
          before do
            allow(described_class).to receive(:retry_criteria_valid?).and_raise(StandardError)
          end

          it "should report error to honeybadger" do
            expect(Honeybadger).to receive(:notify).with(StandardError, hash_including(parameters: {job_arguments: [1, 2, 3]}))
            expect {
              described_class.around_perform_with_honeybadger(1, 2, 3)
            }.to raise_error(StandardError)
          end
        end

      end
    end
  end
end
