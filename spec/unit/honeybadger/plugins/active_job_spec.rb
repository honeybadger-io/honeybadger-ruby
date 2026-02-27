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
    end
  end
end
