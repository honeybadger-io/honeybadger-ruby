require "honeybadger/plugins/active_job"
require "honeybadger/config"

describe "ActiveJob Plugin" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }
  let(:on_load_callbacks) { [] }

  let(:active_job_base) do
    Class.new do
      def self.set_callback(*args, &block)
      end
    end
  end

  let(:rails_app_config) do
    double("app_config",
      active_job: { queue_adapter: :async },
      respond_to?: true
    )
  end

  let(:rails_app) do
    double("app", config: rails_app_config)
  end

  before do
    Honeybadger::Plugin.instances[:active_job].reset!

    stub_const("Rails", Module.new)
    allow(Rails).to receive(:application).and_return(rails_app)

    stub_const("ActiveJob::Base", active_job_base)

    unless defined?(ActiveSupport)
      stub_const("ActiveSupport", Module.new)
    end

    # Stub ActiveSupport::Notifications if needed for insights subscription
    unless defined?(ActiveSupport::Notifications)
      notifications = Module.new do
        def self.subscribe(*args)
        end
      end
      stub_const("ActiveSupport::Notifications", notifications)
    end

    # Track on_load callbacks instead of executing them immediately
    allow(ActiveSupport).to receive(:on_load).with(:active_job) do |*, &block|
      on_load_callbacks << block
    end
  end

  context "when exceptions are enabled" do
    before do
      allow(Honeybadger).to receive(:config).and_return(config)
      config[:"exceptions.enabled"] = true
    end

    it "defers ActiveJob::Base.set_callback via ActiveSupport.on_load(:active_job)" do
      Honeybadger::Plugin.instances[:active_job].load!(config)

      expect(ActiveSupport).to have_received(:on_load).with(:active_job)
      expect(on_load_callbacks).not_to be_empty
    end

    it "does not call ActiveJob::Base.set_callback during plugin load" do
      expect(active_job_base).not_to receive(:set_callback)
      Honeybadger::Plugin.instances[:active_job].load!(config)
    end

    it "calls set_callback when the on_load hook fires" do
      Honeybadger::Plugin.instances[:active_job].load!(config)

      expect(active_job_base).to receive(:set_callback).with(:perform, :around, prepend: true)
      on_load_callbacks.each { |cb| active_job_base.instance_eval(&cb) }
    end
  end

  context "when exceptions are disabled" do
    before do
      allow(Honeybadger).to receive(:config).and_return(config)
      config[:"exceptions.enabled"] = false
    end

    it "does not register any ActiveSupport.on_load(:active_job) callbacks" do
      Honeybadger::Plugin.instances[:active_job].load!(config)

      expect(ActiveSupport).not_to have_received(:on_load).with(:active_job)
      expect(on_load_callbacks).to be_empty
    end

    it "does not call ActiveJob::Base.set_callback" do
      expect(active_job_base).not_to receive(:set_callback)
      Honeybadger::Plugin.instances[:active_job].load!(config)
    end
  end

  describe "metric counters" do
    before do
      Honeybadger::Plugins::ActiveJob.reset_counters!
    end

    describe ".record_metric" do
      it "tracks performed jobs" do
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "success"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_performed]).to eq(1)
        expect(data[:queues]["default"][:performed]).to eq(1)
      end

      it "tracks failed jobs" do
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "failure"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_performed]).to eq(1)
        expect(data[:stats][:jobs_failed]).to eq(1)
        expect(data[:queues]["default"][:performed]).to eq(1)
        expect(data[:queues]["default"][:failed]).to eq(1)
      end

      it "tracks enqueued jobs" do
        Honeybadger::Plugins::ActiveJob.record_metric("enqueue.active_job", {queue_name: "mailers"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_enqueued]).to eq(1)
        expect(data[:queues]["mailers"][:enqueued]).to eq(1)
      end

      it "tracks enqueue_at jobs" do
        Honeybadger::Plugins::ActiveJob.record_metric("enqueue_at.active_job", {queue_name: "default"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_enqueued]).to eq(1)
      end

      it "tracks bulk enqueued jobs from enqueue_all" do
        Honeybadger::Plugins::ActiveJob.record_metric("enqueue_all.active_job", {
          jobs: [
            {queue_name: "default"},
            {queue_name: "default"},
            {queue_name: "mailers"}
          ]
        })

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_enqueued]).to eq(3)
        expect(data[:queues]["default"][:enqueued]).to eq(2)
        expect(data[:queues]["mailers"][:enqueued]).to eq(1)
      end

      it "tracks retried jobs" do
        Honeybadger::Plugins::ActiveJob.record_metric("enqueue_retry.active_job", {queue_name: "default"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_retried]).to eq(1)
        expect(data[:queues]["default"][:retried]).to eq(1)
      end

      it "tracks discarded jobs" do
        Honeybadger::Plugins::ActiveJob.record_metric("discard.active_job", {queue_name: "default"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_discarded]).to eq(1)
        expect(data[:queues]["default"][:discarded]).to eq(1)
      end

      it "tracks retry_stopped jobs" do
        Honeybadger::Plugins::ActiveJob.record_metric("retry_stopped.active_job", {queue_name: "default"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_retry_stopped]).to eq(1)
        expect(data[:queues]["default"][:retry_stopped]).to eq(1)
      end

      it "defaults queue_name to 'default' when missing" do
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {status: "success"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:queues]["default"][:performed]).to eq(1)
      end

      it "accumulates counts across multiple events" do
        3.times { Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "success"}) }
        2.times { Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "failure"}) }

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats][:jobs_performed]).to eq(5)
        expect(data[:stats][:jobs_failed]).to eq(2)
      end

      it "tracks per-queue metrics separately" do
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "success"})
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "mailers", status: "success"})
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "mailers", status: "failure"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:queues]["default"][:performed]).to eq(1)
        expect(data[:queues]["mailers"][:performed]).to eq(2)
        expect(data[:queues]["mailers"][:failed]).to eq(1)
      end
    end

    describe ".flush_counters" do
      it "resets counters after flush" do
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "success"})
        Honeybadger::Plugins::ActiveJob.flush_counters

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats]).to be_empty
        expect(data[:queues]).to be_empty
      end
    end

    describe ".reset_counters!" do
      it "clears all counters" do
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "success"})
        Honeybadger::Plugins::ActiveJob.reset_counters!

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats]).to be_empty
        expect(data[:queues]).to be_empty
      end
    end
  end

  describe "collectors" do
    let(:config) do
      Honeybadger::Config.new(
        logger: NULL_LOGGER,
        debug: true,
        "insights.enabled": true,
        "active_job.insights.enabled": true,
        "active_job.insights.metrics": true,
        "active_job.insights.events": true
      )
    end

    before do
      allow(Honeybadger).to receive(:config).and_return(config)
      config[:"exceptions.enabled"] = true
      Honeybadger::Plugin.instances[:active_job].load!(config)

      Honeybadger::Plugins::ActiveJob.reset_counters!
    end

    it "can execute collectors" do
      Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "success"})

      Honeybadger::Plugin.instances[:active_job].collectors.each do |options, collect_block|
        Honeybadger::Plugin::CollectorExecution.new("active_job", config, options, &collect_block).call
      end
    end

    it "skips collection when no metrics have been recorded" do
      expect(Honeybadger).not_to receive(:event)

      Honeybadger::Plugin.instances[:active_job].collectors.each do |options, collect_block|
        Honeybadger::Plugin::CollectorExecution.new("active_job", config, options, &collect_block).call
      end
    end

    it "emits a stats event when events feature is enabled" do
      Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "success"})

      expect(Honeybadger).to receive(:event).with("stats.active_job", hash_including(jobs_performed: 1))

      Honeybadger::Plugin.instances[:active_job].collectors.each do |options, collect_block|
        Honeybadger::Plugin::CollectorExecution.new("active_job", config, options, &collect_block).call
      end
    end

    context "when metrics feature is disabled" do
      let(:config) do
        Honeybadger::Config.new(
          logger: NULL_LOGGER,
          debug: true,
          "insights.enabled": true,
          "active_job.insights.enabled": true,
          "active_job.insights.metrics": false
        )
      end

      it "does not execute collection" do
        Honeybadger::Plugins::ActiveJob.record_metric("perform.active_job", {queue_name: "default", status: "success"})
        expect(Honeybadger).not_to receive(:event)

        Honeybadger::Plugin.instances[:active_job].collectors.each do |options, collect_block|
          Honeybadger::Plugin::CollectorExecution.new("active_job", config, options, &collect_block).call
        end
      end
    end
  end
end

describe Honeybadger::ActiveJobSubscriber do
  let(:config) do
    Honeybadger::Config.new(
      logger: NULL_LOGGER,
      debug: true,
      "insights.enabled": true,
      "active_job.insights.enabled": true,
      "active_job.insights.events": true,
      "active_job.insights.metrics": true
    )
  end

  let(:subscriber) { described_class.new }

  before do
    allow(Honeybadger).to receive(:config).and_return(config)
    allow(Honeybadger).to receive(:event)
    Honeybadger::Plugins::ActiveJob.reset_counters!
  end

  describe "#record" do
    it "emits an event when events feature is enabled" do
      expect(Honeybadger).to receive(:event).with("perform.active_job", hash_including(duration: 100.0))
      subscriber.record("perform.active_job", {duration: 100.0, job_class: "TestJob", queue_name: "default"})
    end

    context "when events feature is disabled" do
      let(:config) do
        Honeybadger::Config.new(
          logger: NULL_LOGGER,
          debug: true,
          "insights.enabled": true,
          "active_job.insights.enabled": true,
          "active_job.insights.events": false,
          "active_job.insights.metrics": true
        )
      end

      it "does not emit an event" do
        expect(Honeybadger).not_to receive(:event)
        subscriber.record("perform.active_job", {duration: 100.0})
      end
    end
  end

  describe "#record_metrics" do
    it "records perform duration gauge for perform events" do
      expect(subscriber).to receive(:gauge).with("duration.perform.active_job", hash_including(value: 150.5, job_class: "TestJob", queue_name: "default", status: "success"))
      subscriber.record_metrics("perform.active_job", {duration: 150.5, job_class: "TestJob", queue_name: "default", status: "success"})
    end

    it "records enqueue duration gauge for enqueue events" do
      expect(subscriber).to receive(:gauge).with("duration.enqueue.active_job", hash_including(value: 5.2, job_class: "TestJob", queue_name: "default"))
      subscriber.record_metrics("enqueue.active_job", {duration: 5.2, job_class: "TestJob", queue_name: "default"})
    end

    it "records enqueue duration gauge for enqueue_at events" do
      expect(subscriber).to receive(:gauge).with("duration.enqueue.active_job", hash_including(value: 3.1, job_class: "TestJob", queue_name: "default"))
      subscriber.record_metrics("enqueue_at.active_job", {duration: 3.1, job_class: "TestJob", queue_name: "default"})
    end

    it "records duration gauge for enqueue_retry events" do
      expect(subscriber).to receive(:gauge).with("duration.enqueue_retry.active_job", hash_including(value: 2.0, job_class: "TestJob", queue_name: "default"))
      subscriber.record_metrics("enqueue_retry.active_job", {duration: 2.0, job_class: "TestJob", queue_name: "default"})
    end

    it "records duration gauge for discard events" do
      expect(subscriber).to receive(:gauge).with("duration.discard.active_job", hash_including(value: 1.5, job_class: "TestJob", queue_name: "default"))
      subscriber.record_metrics("discard.active_job", {duration: 1.5, job_class: "TestJob", queue_name: "default"})
    end

    it "records duration gauge for retry_stopped events" do
      expect(subscriber).to receive(:gauge).with("duration.retry_stopped.active_job", hash_including(value: 4.3, job_class: "TestJob", queue_name: "default"))
      subscriber.record_metrics("retry_stopped.active_job", {duration: 4.3, job_class: "TestJob", queue_name: "default"})
    end

    it "tracks metrics in ActiveJob counters" do
      allow(subscriber).to receive(:gauge)
      subscriber.record_metrics("perform.active_job", {duration: 100.0, job_class: "TestJob", queue_name: "default", status: "success"})

      data = Honeybadger::Plugins::ActiveJob.flush_counters
      expect(data[:stats][:jobs_performed]).to eq(1)
    end

    context "when metrics feature is disabled" do
      let(:config) do
        Honeybadger::Config.new(
          logger: NULL_LOGGER,
          debug: true,
          "insights.enabled": true,
          "active_job.insights.enabled": true,
          "active_job.insights.events": true,
          "active_job.insights.metrics": false
        )
      end

      it "does not record gauges" do
        expect(subscriber).not_to receive(:gauge)
        subscriber.record_metrics("perform.active_job", {duration: 100.0, job_class: "TestJob", queue_name: "default", status: "success"})
      end

      it "does not track metrics in counters" do
        subscriber.record_metrics("perform.active_job", {duration: 100.0, job_class: "TestJob", queue_name: "default", status: "success"})

        data = Honeybadger::Plugins::ActiveJob.flush_counters
        expect(data[:stats]).to be_empty
      end
    end
  end
end
