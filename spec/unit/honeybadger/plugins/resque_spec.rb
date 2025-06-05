require "honeybadger/plugins/resque"
require "honeybadger/config"
require "honeybadger/agent"

class TestWorker
  extend Honeybadger::Plugins::Resque::Extension
  def self.retry_criteria_valid?(e)
  end
end

describe TestWorker do
  describe "::on_failure_with_honeybadger" do
    let(:error) { RuntimeError.new("Failure in Honeybadger resque_spec") }

    shared_examples_for "reports exceptions" do
      specify do
        expect(Honeybadger).to receive(:notify).with(error, hash_including(parameters: {job_arguments: [1, 2, 3]}, sync: true))
        described_class.on_failure_with_honeybadger(error, 1, 2, 3)
      end
    end

    shared_examples_for "does not report exceptions" do
      specify do
        expect(Honeybadger).not_to receive(:notify)
        expect {
          described_class.around_perform_with_honeybadger(1, 2, 3) do
            fail "foo"
          end
        }.to raise_error(RuntimeError)
      end
    end

    it_behaves_like "reports exceptions"

    it "clears the context" do
      expect {
        Honeybadger.context(badgers: true)
        described_class.on_failure_with_honeybadger(error, 1, 2, 3)
      }.not_to change { Honeybadger::ContextManager.current.get_context }.from(nil)
    end

    describe "with worker not extending Resque::Plugins::Retry" do
      context "when send exceptions on retry enabled" do
        before { ::Honeybadger.config[:"resque.resque_retry.send_exceptions_when_retrying"] = true }
        it_behaves_like "reports exceptions"
      end

      context "when send exceptions on retry disabled" do
        before { ::Honeybadger.config[:"resque.resque_retry.send_exceptions_when_retrying"] = false }
        it_behaves_like "reports exceptions"
      end
    end

    describe "with worker extending Resque::Plugins::Retry" do
      let(:retry_criteria_valid) { false }

      before do
        allow(described_class).to receive(:retry_criteria_valid?)
          .and_return(retry_criteria_valid)
      end

      context "when send exceptions on retry enabled" do
        before { ::Honeybadger.config[:"resque.resque_retry.send_exceptions_when_retrying"] = true }

        context "with retry criteria invalid" do
          it_behaves_like "reports exceptions"
        end

        context "with retry criteria valid" do
          let(:retry_criteria_valid) { true }
          it_behaves_like "reports exceptions"
        end
      end

      context "when send exceptions on retry disabled" do
        before { ::Honeybadger.config[:"resque.resque_retry.send_exceptions_when_retrying"] = false }

        context "with retry criteria invalid" do
          it_behaves_like "reports exceptions"
        end

        context "with retry criteria valid" do
          let(:retry_criteria_valid) { true }
          it_behaves_like "does not report exceptions"
        end

        context "and retry_criteria_valid? raises exception" do
          it "should report raised error to honeybadger" do
            other_error = StandardError.new("stubbed Honeybadger error in retry_criteria_valid?")
            allow(described_class).to receive(:retry_criteria_valid?).and_raise(other_error)
            expect(Honeybadger).to receive(:notify).with(other_error, hash_including(parameters: {job_arguments: [1, 2, 3]}, sync: true))
            described_class.on_failure_with_honeybadger(error, 1, 2, 3)
          end
        end
      end
    end
  end

  describe "::around_perform_with_honeybadger" do
    it "flushes pending errors before worker dies" do
      expect(Honeybadger).to receive(:flush)

      described_class.around_perform_with_honeybadger do
      end
    end

    it "raises exceptions" do
      expect {
        described_class.around_perform_with_honeybadger do
          fail "foo"
        end
      }.to raise_error(RuntimeError, /foo/)
    end
  end

  describe "::after_perform_with_honeybadger" do
    it "clears the context" do
      expect {
        Honeybadger.context(badgers: true)
        described_class.after_perform_with_honeybadger
      }.not_to change { Honeybadger::ContextManager.current.get_context }.from(nil)
    end
  end
end
