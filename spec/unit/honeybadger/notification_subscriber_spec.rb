require "honeybadger/notification_subscriber"

module ActiveSupport
  module Cache; end
end

describe Honeybadger::ActiveSupportCacheMultiSubscriber do
  context "with a cache_write_multi.active_support payload" do
    let(:payload) do
      obj = Object.new
      {
        key: {"one" => "data", "object.cache_key" => obj},
        store: "cache-store-name"
      }
    end

    before do
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:key].keys[0]).and_return("one")
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:key].keys[1]).and_return("foo/bar")
    end

    subject { described_class.new.format_payload("cache_write_multi.active_support", payload) }

    it "returns a payload with all keys expanded and without cache values" do
      expect(subject).to be_a(Hash)
      expect(subject[:key]).to eq(%w[one foo/bar])
      expect(subject[:store]).to eq("cache-store-name")
    end
  end

  context "with a cache_read_multi.active_support payload" do
    let(:payload) do
      {
        key: ["one", Object.new],
        hits: ["one"],
        store: "cache-store-name",
        super_operation: :fetch_multi
      }
    end

    before do
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:key][0]).and_return("one")
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:key][1]).and_return("foo/bar")
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:hits][0]).and_return("one")
    end

    subject { described_class.new.format_payload("cache_read_multi.active_support", payload) }

    it "returns a payload with all keys expanded" do
      expect(subject).to be_a(Hash)
      expect(subject[:key]).to eq(%w[one foo/bar])
      expect(subject[:hits]).to eq(%w[one])
      expect(subject[:store]).to eq("cache-store-name")
      expect(subject[:super_operation]).to eq(:fetch_multi)
    end
  end
end

describe Honeybadger::ActiveJobSubscriber do
  let(:adapter) { double("adapter", class: Class) }

  context "with a single job payload" do
    let(:job) { double("job", class: String, job_id: "123", queue_name: "default") }
    let(:payload) do
      {
        job: job,
        adapter: adapter,
        extra_data: "test"
      }
    end

    subject { described_class.new.format_payload("enqueue.active_job", payload) }

    it "returns a payload with job data" do
      expect(subject).to eq({
        adapter_class: "Class",
        job_class: "String",
        job_id: "123",
        queue_name: "default",
        extra_data: "test"
      })
    end
  end

  context "with a jobs payload (enqueue_all)" do
    let(:job1) { double("job1", class: String, job_id: "123", queue_name: "default") }
    let(:job2) { double("job2", class: Integer, job_id: "456", queue_name: "priority") }
    let(:payload) do
      {
        jobs: [job1, job2],
        adapter: adapter,
        extra_data: "test"
      }
    end

    subject { described_class.new.format_payload("enqueue_all.active_job", payload) }

    it "returns a payload with jobs array" do
      expect(subject).to eq({
        adapter_class: "Class",
        jobs: [
          {job_class: "String", job_id: "123", queue_name: "default"},
          {job_class: "Integer", job_id: "456", queue_name: "priority"}
        ],
        extra_data: "test"
      })
    end
  end

  context "with nil job payload" do
    let(:payload) do
      {
        job: nil,
        adapter: adapter,
        extra_data: "test"
      }
    end

    subject { described_class.new.format_payload("other.active_job", payload) }

    it "returns payload without job data" do
      expect(subject).to eq({
        adapter_class: "Class",
        extra_data: "test"
      })
    end
  end

  context "with no job or jobs payload" do
    let(:payload) do
      {
        adapter: adapter,
        extra_data: "test"
      }
    end

    subject { described_class.new.format_payload("other.active_job", payload) }

    it "returns payload without job data" do
      expect(subject).to eq({
        adapter_class: "Class",
        extra_data: "test"
      })
    end
  end

  context "with nil adapter" do
    let(:job) { double("job", class: String, job_id: "123", queue_name: "default") }
    let(:payload) do
      {
        job: job,
        adapter: nil,
        extra_data: "test"
      }
    end

    subject { described_class.new.format_payload("other.active_job", payload) }

    it "handles nil adapter gracefully" do
      expect(subject).to eq({
        adapter_class: nil,
        job_class: "String",
        job_id: "123",
        queue_name: "default",
        extra_data: "test"
      })
    end
  end

  context "with perform.active_job event with exception" do
    let(:job) { double("job", class: String, job_id: "123", queue_name: "default") }
    let(:exception) { StandardError.new("Job failed") }
    let(:payload) do
      {
        job: job,
        adapter: adapter,
        exception_object: exception
      }
    end

    subject { described_class.new.format_payload("perform.active_job", payload) }

    it "sets status to failure" do
      expect(subject[:status]).to eq("failure")
    end
  end

  context "with perform.active_job event without exception" do
    let(:job) { double("job", class: String, job_id: "123", queue_name: "default") }
    let(:payload) do
      {
        job: job,
        adapter: adapter
      }
    end

    subject { described_class.new.format_payload("perform.active_job", payload) }

    it "sets status to success" do
      expect(subject[:status]).to eq("success")
    end
  end

  context "with non-perform event" do
    let(:job) { double("job", class: String, job_id: "123", queue_name: "default") }
    let(:payload) do
      {
        job: job,
        adapter: adapter
      }
    end

    subject { described_class.new.format_payload("enqueue.active_job", payload) }

    it "does not include status field" do
      expect(subject).not_to have_key(:status)
    end
  end
end

describe Honeybadger::ActiveRecordSubscriber do
  let(:connection) { double("connection", adapter_name: "PostgreSQL") }

  describe "#format_payload" do
    it "obfuscates the query" do
      payload = {sql: "SELECT * FROM users WHERE id = 1", connection: connection}
      expect(described_class.new.format_payload("sql.active_record", payload)[:query]).to eq "SELECT * FROM users WHERE id = ?"
    end

    context "when the query is longer than sql.max_length" do
      before { Honeybadger.config[:"sql.max_length"] = 20 }
      after { Honeybadger.config[:"sql.max_length"] = Honeybadger::Config::DEFAULTS[:"sql.max_length"] }

      it "truncates the query instead of obfuscating it" do
        payload = {sql: "SELECT * FROM users WHERE name = 'secret'", connection: connection}
        query = described_class.new.format_payload("sql.active_record", payload)[:query]
        expect(query).to start_with("SELECT * FROM users WHERE name = ")
        expect(query).to include("[truncated")
        expect(query).not_to include("secret")
      end
    end
  end

  describe "#finish" do
    let(:subscriber) { described_class.new }
    let(:payload) { {sql: "SELECT 1", connection: connection} }

    before do
      allow(Honeybadger).to receive(:event)
      subscriber.start("sql.active_record", "id", payload)
    end

    it "does not raise when formatting the payload fails" do
      allow(subscriber).to receive(:format_payload).and_raise(RuntimeError.new("regexp match timeout"))
      expect { subscriber.finish("sql.active_record", "id", payload) }.not_to raise_error
    end

    it "logs the error when formatting the payload fails" do
      allow(subscriber).to receive(:format_payload).and_raise(RuntimeError.new("regexp match timeout"))
      expect(Honeybadger.config.logger).to receive(:error).with(/regexp match timeout/)
      subscriber.finish("sql.active_record", "id", payload)
    end

    it "records the event when nothing fails" do
      expect(Honeybadger).to receive(:event).with("sql.active_record", hash_including(query: "SELECT ?"))
      subscriber.finish("sql.active_record", "id", payload)
    end
  end
end
