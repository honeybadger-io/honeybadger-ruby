require "honeybadger/notification_subscriber"

module ActiveSupport
  module Cache; end
end

RSpec.describe Honeybadger::ActiveSupportCacheMultiSubscriber do
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

RSpec.describe Honeybadger::ActiveJobSubscriber do
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
end
