require 'honeybadger/plugins/resque'

class TestWorker
  extend Honeybadger::Plugins::Resque::Extension
end

describe TestWorker do
  describe "::around_perform_with_honeybadger" do
    it "clears the context" do
      expect {
        described_class.around_perform_with_honeybadger do
          Honeybadger.context(badgers: true)
        end
      }.not_to change { Thread.current[:__honeybadger_context] }.from(nil)
    end

    it "reports exceptions" do
      expect(Honeybadger).to receive(:notify).with(kind_of(RuntimeError), hash_including(parameters: {job_arguments: [1, 2, 3]}))
      expect {
        described_class.around_perform_with_honeybadger(1, 2, 3) do
          fail 'foo'
        end
      }.to raise_error
    end

    it "raises exceptions" do
      expect {
        described_class.around_perform_with_honeybadger do
          fail 'foo'
        end
      }.to raise_error
    end
  end
end
