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
