require "honeybadger/agent"
require "honeybadger/events_worker"
require "timecop"

NULL_BLOCK = proc {}.freeze

describe Honeybadger::Agent do
  describe "class methods" do
    subject { described_class }

    its(:instance) { should be_a(Honeybadger::Agent) }
  end

  describe "#check_in" do
    it "parses check_in id from a url" do
      stub_request(:get, "https://api.honeybadger.io/v1/check_in/1MqIo1")
        .to_return(status: 200)

      config = Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER)
      instance = described_class.new(config)

      instance.check_in("https://api.honeybadger.io/v1/check_in/1MqIo1")
    end

    it "returns true for successful check ins" do
      stub_request(:get, "https://api.honeybadger.io/v1/check_in/foobar")
        .to_return(status: 200)

      config = Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER)
      instance = described_class.new(config)

      expect(instance.check_in("foobar")).to eq(true)
      expect(instance.check_in("/foobar")).to eq(true)
      expect(instance.check_in("/foobar/")).to eq(true)
    end

    it "returns false for failed check ins" do
      stub_request(:get, "https://api.honeybadger.io/v1/check_in/danny")
        .to_return(status: 400)

      config = Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER)
      instance = described_class.new(config)

      expect(instance.check_in("danny")).to eq(false)
    end
  end

  describe "#track_deployment" do
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER) }
    subject(:instance) { described_class.new(config) }

    it "returns true for successful deployment tracking" do
      stub_request(:post, "https://api.honeybadger.io/v1/deploys")
        .to_return(status: 200)

      expect(instance.track_deployment).to eq(true)
    end

    it "returns false for unsuccessful deployment tracking" do
      stub_request(:post, "https://api.honeybadger.io/v1/deploys")
        .to_return(status: 400)

      expect(instance.track_deployment).to eq(false)
    end

    it "passes the revision to the servce" do
      allow_any_instance_of(Honeybadger::Util::HTTP).to receive(:compress) { |_, body| body }
      stub_request(:post, "https://api.honeybadger.io/v1/deploys")
        .with(body: {environment: nil, revision: "1234", local_username: nil, repository: nil})
        .to_return(status: 200)

      expect(instance.track_deployment(revision: "1234")).to eq(true)
    end
  end

  describe "#context" do
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER) }
    subject(:instance) { described_class.new(config) }

    it "sets the context" do
      instance.context({a: "context"})
      expect(instance.get_context).to eq({a: "context"})
    end

    it "allows chaining" do
      expect(instance.context({a: "context"})).to eq(instance)
    end

    context "with local context" do
      it "returns the return value of the block" do
        expect(instance.context({bar: :baz}) { :return_value }).to eq(:return_value)
      end
    end
  end

  describe "#clear!" do
    it "clears all transactional data" do
      config = Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER)
      instance = described_class.new(config)
      instance.context({a: "context"})
      instance.add_breadcrumb("Chomp")

      instance.clear!

      expect(instance.get_context).to be nil
      expect(instance.breadcrumbs.to_a).to be_empty
    end
  end

  describe "#notify" do
    it "generates a backtrace" do
      config = Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER)
      instance = described_class.new(config)

      expect(instance.worker).to receive(:push) do |notice|
        expect(notice.backtrace.to_a[0]).to match("lib/honeybadger/agent.rb")
      end

      instance.notify(error_message: "testing backtrace generation")
    end

    it "does not mutate passed in opts" do
      opts = {error_message: "test"}
      prev = opts.dup
      instance = described_class.new(Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER))
      instance.notify("test", **opts)
      expect(prev).to eq(opts)
    end

    it "accepts keyword arguments as second argument" do
      opts = {tags: 'testing, kwargs'}
      config = Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER)
      instance = described_class.new(config)

      expect(instance.worker).to receive(:push) do |notice|
        expect(notice.error_message).to match("test")
        expect(notice.tags).to eq(["testing", "kwargs"])
      end
      instance.notify("test", **opts)
    end

    it "does not report an already reported exception" do
      instance = described_class.new(Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER))
      exception = RuntimeError.new
      notice_id = "4g09ko4f"
      exception.instance_variable_set(:@__hb_notice_id, notice_id)
      expect(instance.notify(exception)).to be notice_id
      expect(Honeybadger::Notice).to_not receive(:new)
    end

    it "calls all of the before notify hooks before sending" do
      hooks = [spy("hook one", arity: 1), spy("hook two", arity: 1), spy("hook three", arity: 1)]
      instance = described_class.new(Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER))
      instance.configure do |config|
        hooks.each { |hook| config.before_notify(hook) }
      end

      instance.notify(error_message: "testing before notify hooks")

      hooks.each do |hook|
        expect(hook).to have_received(:call).with(instance_of(Honeybadger::Notice))
      end
    end

    it "continues processing even if a before notify hook throws an error" do
      hook = ->(notice) { raise ArgumentError, "this was incorrect" }
      instance = described_class.new(Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER))
      instance.configure do |config|
        config.before_notify(hook)
      end

      expect { instance.notify(error_message: "testing error-raising before notify hook") }.not_to raise_error
    end

    it "halts the callback chain when a notice is halted" do
      before_halt_hooks = [spy("hook one", arity: 1), spy("hook two", arity: 1)]
      halt_hook = ->(notice) { notice.halt! }
      after_halt_hooks = [spy("hook three", arity: 1), spy("hook four", arity: 1)]
      instance = described_class.new(Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER))
      instance.configure do |config|
        before_halt_hooks.each { |hook| config.before_notify(hook) }
        config.before_notify(halt_hook)
        after_halt_hooks.each { |hook| config.before_notify(hook) }
      end

      instance.notify(error_message: "testing error-raising before notify hook")

      before_halt_hooks.each do |hook|
        expect(hook).to have_received(:call).with(instance_of(Honeybadger::Notice))
      end

      after_halt_hooks.each do |hook|
        expect(hook).not_to have_received(:call).with(instance_of(Honeybadger::Notice))
      end
    end

    describe "breadcrumbs" do
      let(:breadcrumbs) { instance_double(Honeybadger::Breadcrumbs::Collector) }
      let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, "breadcrumbs.enabled": true) }

      subject { described_class.new(config) }

      it "stores notice breadcrumb and passes along duplicated breadcrumbs" do
        duped_breadcrumbs = double(each: [])
        expect(subject).to receive(:breadcrumbs).and_return(breadcrumbs)
        expect(subject).to receive(:add_breadcrumb).with(
          "Honeybadger Notice",
          metadata: {error_message: "passed breadcrumbs?"},
          category: "notice"
        )
        expect(breadcrumbs).to receive(:dup).and_return(duped_breadcrumbs)
        expect(Honeybadger::Notice).to receive(:new).with(config, hash_including(breadcrumbs: duped_breadcrumbs)).and_call_original

        subject.notify(error_message: "passed breadcrumbs?")
      end
    end
  end

  context "breadcrumbs" do
    let(:breadcrumbs) { instance_double(Honeybadger::Breadcrumbs::Collector, clear!: nil) }
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER) }
    subject { described_class.new(config) }

    before do
      Thread.current[:__hb_breadcrumbs] = nil
    end

    describe "#breadcrumbs" do
      context "when local_context: true" do
        let(:config) { {local_context: true} }

        it "creates instance local breadcrumb" do
          subject.breadcrumbs
          expect(Thread.current[:__hb_breadcrumbs]).to be nil
        end

        it "instantiates the breadcrumb collector with the right config" do
          allow(Honeybadger::Breadcrumbs::Collector).to receive(:new).and_call_original
          subject.breadcrumbs
          expect(Honeybadger::Breadcrumbs::Collector).to have_received(:new).with(instance_of(Honeybadger::Config))
        end
      end

      it "stores breadcrumbs in thread local" do
        bc = subject.breadcrumbs
        expect(Thread.current[:__hb_breadcrumbs]).to eq(bc)
      end
    end

    describe "#add_breadcrumb" do
      before do
        Timecop.freeze
        allow(subject).to receive(:breadcrumbs).and_return(breadcrumbs)
      end

      after { Timecop.return }

      it "adds breadcrumb to manager" do
        crumb = Honeybadger::Breadcrumbs::Breadcrumb.new(category: "neat", message: "This is the message", metadata: {a: "b"})
        expect(breadcrumbs).to receive(:add!).with(crumb)

        subject.add_breadcrumb("This is the message", metadata: {a: "b"}, category: "neat")
      end

      it "has sane defaults" do
        crumb = Honeybadger::Breadcrumbs::Breadcrumb.new(category: "custom", message: "Basic Message", metadata: {})
        expect(breadcrumbs).to receive(:add!).with(crumb)

        subject.add_breadcrumb("Basic Message")
      end

      it "sanitizes breadcrumb before adding" do
        sanitizer = instance_double(Honeybadger::Util::Sanitizer)
        allow(breadcrumbs).to receive(:add!)
        expect(Honeybadger::Util::Sanitizer).to receive(:new).with(max_depth: 2).and_return(sanitizer)
        expect(sanitizer).to receive(:sanitize).with(hash_including({message: "Breadcrumb"})).and_return({})
        expect(Honeybadger::Breadcrumbs::Breadcrumb).to receive(:new)

        subject.add_breadcrumb("Breadcrumb")
      end
    end
  end

  context "#event" do
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, backend: :debug) }
    let(:events_worker) { double(Honeybadger::EventsWorker.new(config)) }
    let(:instance) { Honeybadger::Agent.new(config) }

    subject { instance }

    before do
      allow(instance).to receive(:events_worker).and_return(events_worker)
    end

    context "with event type as first argument" do
      it "logs an event" do
        expect(events_worker).to receive(:push) do |msg|
          expect(msg[:event_type]).to eq("test_event")
          expect(msg[:some_data]).to eq("is here")
          expect(msg[:ts]).not_to be_nil
        end
        subject.event("test_event", some_data: "is here")
      end
    end

    context "with payload as first argument" do
      it "logs an event" do
        expect(events_worker).to receive(:push) do |msg|
          expect(msg[:event_type]).to eq("test_event")
          expect(msg[:some_data]).to eq("is here")
          expect(msg[:ts]).not_to be_nil
        end
        subject.event(event_type: "test_event", some_data: "is here")
      end
    end

    describe "ignoring events using before_event callback" do
      let(:halt_hook) { ->(event) { event.halt! } }

      before { subject.configure { |config| config.before_event(halt_hook) } }
      after { subject.event(event_type: "event_type", some_data: "is here") }

      it "does not push an event" do
        expect(events_worker).not_to receive(:push)
      end
    end

    describe "sampling events using events.sample_rate config" do
      let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, backend: :debug, "events.sample_rate": sample_rate) }
      let(:payload) { {some_data: "is here"} }
      let(:event_type) { "test_event" }

      context "when sample rate is 100" do
        let(:sample_rate) { 100 }

        it "pushes all events" do
          expect(events_worker).to receive(:push) do |msg|
            expect(msg[:event_type]).to eq("test_event")
            expect(msg[:some_data]).to eq("is here")
          end
          subject.event(payload.merge(event_type: event_type))
        end
      end

      context "when sample rate is 0" do
        let(:sample_rate) { 0 }

        it "does not push any events" do
          expect(events_worker).not_to receive(:push)
          subject.event(payload.merge(event_type: event_type))
        end
      end

      context "with request_id in payload" do
        let(:sample_rate) { 50 }
        let(:payload) { {some_data: "is here", request_id: "test-request-id"} }

        it "uses consistent sampling based on request_id" do
          expect(Zlib).to receive(:crc32).with("test-request-id").and_return(49) # 49 % 100 < 50, so it should be included
          expect(events_worker).to receive(:push)
          subject.event(payload.merge(event_type: event_type))
        end

        it "consistently samples events with the same request_id" do
          expect(Zlib).to receive(:crc32).with("test-request-id").and_return(75) # 75 % 100 > 50, so it should be excluded
          expect(events_worker).not_to receive(:push)
          subject.event(payload.merge(event_type: event_type))
        end
      end

      context "without request_id in payload" do
        let(:sample_rate) { 50 }

        it "uses random sampling" do
          # Mock rand to return a value that would include the event
          expect(subject).to receive(:rand).with(100).and_return(25) # 25 < 50, so it should be included
          expect(events_worker).to receive(:push)
          subject.event(payload.merge(event_type: event_type))
        end

        it "randomly excludes events based on sample rate" do
          # Mock rand to return a value that would exclude the event
          expect(subject).to receive(:rand).with(100).and_return(75) # 75 > 50, so it should be excluded
          expect(events_worker).not_to receive(:push)
          subject.event(payload.merge(event_type: event_type))
        end
      end

      context "with sample rate override in event metadata" do
        let(:sample_rate) { 0 } # Global sample rate is 0 (no events)
        let(:payload) { {some_data: "is here", _hb: {sample_rate: 100}} } # But this event has override to 100%

        it "uses the override sample rate from event metadata" do
          expect(events_worker).to receive(:push) do |msg|
            # Verify that _hb metadata is removed
            expect(msg).not_to have_key(:_hb)
            expect(msg[:event_type]).to eq("test_event")
            expect(msg[:some_data]).to eq("is here")
          end
          subject.event(payload.merge(event_type: event_type))
        end
      end

      context "with invalid sample rate override in event metadata" do
        let(:sample_rate) { 100 } # Global sample rate is 100% (all events)
        let(:payload) { {some_data: "is here", _hb: {sample_rate: "invalid"}} } # Invalid override

        it "falls back to global sample rate" do
          expect(events_worker).to receive(:push) do |msg|
            # Verify that _hb metadata is removed
            expect(msg).not_to have_key(:_hb)
            expect(msg[:event_type]).to eq("test_event")
            expect(msg[:some_data]).to eq("is here")
          end
          subject.event(payload.merge(event_type: event_type))
        end
      end

      context "with metric events" do
        let(:sample_rate) { 0 } # Global sample rate is 0 (no events)
        let(:event_type) { "metric.hb" }
        let(:payload) { {metric_name: "test.metric", value: 42} }

        it "always sends metric events regardless of sample rate" do
          expect(events_worker).to receive(:push) do |msg|
            expect(msg[:event_type]).to eq("metric.hb")
            expect(msg[:metric_name]).to eq("test.metric")
            expect(msg[:value]).to eq(42)
          end
          subject.event(payload.merge(event_type: event_type))
        end
      end
    end

    describe "ignoring events using events.ignore config" do
      let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, backend: :debug, "events.ignore": ignored_events) }
      let(:payload) { {some_data: "is here"} }

      after { subject.event(payload.merge(event_type: event_type)) }

      context "when configured with an event type matching string" do
        let(:ignored_events) { ["report.system"] }
        let(:event_type) { "report.system" }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "when configured with an event type non-matching string" do
        let(:ignored_events) { ["non-matching"] }
        let(:event_type) { "report.system" }

        it "does push an event" do
          expect(events_worker).to receive(:push)
        end
      end

      context "when configured with an event type matching regex" do
        let(:ignored_events) { [/.*\.system/] }
        let(:event_type) { "report.system" }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "when configured with an event type non-matching regex" do
        let(:ignored_events) { [/.*\.foo/] }
        let(:event_type) { "report.system" }

        it "does push an event" do
          expect(events_worker).to receive(:push)
        end
      end

      context "when event type is nil" do
        let(:ignored_events) { [/test/] }
        let(:event_type) { nil }

        it "does push an event" do
          expect(events_worker).to receive(:push)
        end
      end

      context "when configured with a hash" do
        let(:ignored_events) { [{"event_type" => "report.system"}] }
        let(:event_type) { "report.system" }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "when configured with a hash with a nested payload" do
        let(:ignored_events) { [{"nested" => {"data" => "test"}}] }
        let(:event_type) { "report.system" }
        let(:payload) { {nested: {data: "test"}} }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "when configured with a hash and regex with a nested payload" do
        let(:ignored_events) { [{"nested" => {"data" => /test.*/}}] }
        let(:event_type) { "report.system" }
        let(:payload) { {nested: {data: "test-report"}} }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "when configured with a hash with string keys" do
        let(:ignored_events) { [{"nested" => {"data" => "test"}}] }
        let(:event_type) { "report.system" }
        let(:payload) { {nested: {"data" => "test"}} }

        it "does push an event" do
          expect(events_worker).to receive(:push)
        end
      end

      context "by default ignores Rails::HealthController" do
        let(:ignored_events) { [] }
        let(:event_type) { "process_action.action_controller" }
        let(:payload) { {controller: "Rails::HealthController"} }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "by default ignores active record BEGIN events" do
        let(:ignored_events) { [] }
        let(:event_type) { "sql.active_record" }
        let(:payload) { {query: "BEGIN"} }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "by default ignores active record COMMIT events" do
        let(:ignored_events) { [] }
        let(:event_type) { "sql.active_record" }
        let(:payload) { {query: "COMMIT"} }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "by default ignores solid_queue processor sql events" do
        let(:ignored_events) { [] }
        let(:event_type) { "sql.active_record" }
        let(:payload) { {query: 'UPDATE "solid_queue_processes" SET "last_heartbeat_at" = ? WHERE "solid_queue_processes"."id" = ?'} }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "by default ignores good_job processor sql events" do
        let(:ignored_events) { [] }
        let(:event_type) { "sql.active_record" }
        let(:payload) { {query: 'SELECT * FROM "good_jobs"'} }

        it "does not push an event" do
          expect(events_worker).not_to receive(:push)
        end
      end

      context "override default ignores" do
        let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, backend: :debug, "events.ignore_only": ignore_only) }
        let(:ignore_only) { [] }
        let(:event_type) { "sql.active_record" }
        let(:payload) { {query: "COMMIT"} }

        it "does not push an event" do
          expect(events_worker).to receive(:push)
        end
      end
    end
  end

  context "#collect" do
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, debug: true, "insights.enabled": true) }
    let(:metrics_worker) { double(Honeybadger::MetricsWorker.new(config)) }
    let(:instance) { Honeybadger::Agent.new(config) }
    let(:collection_execution) { double(Honeybadger::Plugin::CollectorExecution) }

    subject { instance }

    before do
      allow(instance).to receive(:metrics_worker).and_return(metrics_worker)
    end

    context "with a collection execution instance" do
      it "adds to the worker" do
        expect(metrics_worker).to receive(:push) do |msg|
          expect(msg).to eq(collection_execution)
        end
        subject.collect(collection_execution)
      end
    end
  end

  context do
    let!(:instance) { described_class.new(config) }
    let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

    subject { instance }

    before do
      allow(config.logger).to receive(:debug)
    end

    after { instance.stop(true) }

    describe "#initialize" do
      describe "#worker" do
        subject { instance.worker }

        it { should be_a Honeybadger::Worker }
      end
    end

    describe "#flush" do
      subject { instance.flush(&block) }

      context "when no block is given" do
        let(:block) { nil }
        it { should eq true }

        it "flushes worker" do
          expect(instance.worker).to receive(:flush)
          subject
        end
      end

      context "when no block is given" do
        let(:block) { proc { expecting.call } }
        let(:expecting) { double(call: true) }

        it { should eq true }

        it "executes the block" do
          expect(expecting).to receive(:call)
          subject
        end

        it "flushes worker" do
          expect(instance.worker).to receive(:flush)
          subject
        end
      end

      context "when an exception occurs" do
        let(:block) { proc { fail "oops" } }

        it "flushes worker" do
          expect(instance.worker).to receive(:flush)
          expect { subject }.to raise_error(/oops/)
        end
      end
    end

    describe "#exception_filter" do
      it "configures the exception_filter callback" do
        expect { instance.exception_filter(&NULL_BLOCK) }.to change(instance.config, :exception_filter).from(nil).to(NULL_BLOCK)
      end
    end

    describe "#exception_fingerprint" do
      it "configures the exception_fingerprint callback" do
        expect { instance.exception_fingerprint(&NULL_BLOCK) }.to change(instance.config, :exception_fingerprint).from(nil).to(NULL_BLOCK)
      end
    end

    describe "#backtrace_filter" do
      it "configures the backtrace_filter callback" do
        expect { instance.backtrace_filter(&NULL_BLOCK) }.to change(instance.config, :backtrace_filter).from(nil).to(NULL_BLOCK)
      end
    end
  end

  context "#event_context" do
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, backend: :debug) }
    let(:instance) { Honeybadger::Agent.new(config) }

    subject { instance }

    it "sets event context" do
      subject.event_context(user_id: 123)
      expect(subject.get_event_context).to eq({user_id: 123})
    end

    it "merges event context" do
      subject.event_context(user_id: 123)
      subject.event_context(email: "test@example.com")
      expect(subject.get_event_context).to eq({user_id: 123, email: "test@example.com"})
    end

    it "returns self when no block given" do
      expect(subject.event_context(user_id: 123)).to eq(subject)
    end

    it "executes block with local context" do
      result = subject.event_context(user_id: 123) do
        # Inside the block, we should have the local context
        expect(subject.get_event_context).to eq({user_id: 123})
        "block result"
      end
      expect(result).to eq("block result")
      # After the block, the context should be cleared (local context only)
      expect(subject.get_event_context).to eq({})
    end

    it "clears local context after block execution" do
      subject.event_context(user_id: 123)
      subject.event_context(email: "test@example.com") do
        # Local context should be merged
        expect(subject.get_event_context).to eq({user_id: 123, email: "test@example.com"})
      end
      # Only global context should remain
      expect(subject.get_event_context).to eq({user_id: 123})
    end

    it "handles objects with to_honeybadger_context method" do
      user = double("User")
      allow(user).to receive(:to_honeybadger_context).and_return({user_id: 456, name: "John"})

      subject.event_context(user)
      expect(subject.get_event_context).to eq({user_id: 456, name: "John"})
    end

    it "handles nested context objects" do
      inner_object = double("InnerObject")
      allow(inner_object).to receive(:to_honeybadger_context).and_return({inner: "value"})

      outer_object = double("OuterObject")
      allow(outer_object).to receive(:to_honeybadger_context).and_return({outer: "value", nested: inner_object})

      subject.event_context(outer_object)
      expect(subject.get_event_context).to eq({outer: "value", nested: {inner: "value"}})
    end
  end

  context "#get_event_context" do
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, backend: :debug) }
    let(:instance) { Honeybadger::Agent.new(config) }

    subject { instance }

    it "returns nil when no event context is set" do
      expect(subject.get_event_context).to be_nil
    end

    it "returns event context when set" do
      subject.event_context(user_id: 123)
      expect(subject.get_event_context).to eq({user_id: 123})
    end
  end

  context "#event with context" do
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, backend: :debug, "events.attach_hostname": false) }
    let(:events_worker) { double(Honeybadger::EventsWorker.new(config)) }
    let(:instance) { Honeybadger::Agent.new(config) }

    subject { instance }

    before do
      allow(instance).to receive(:events_worker).and_return(events_worker)
    end

    it "does not include global context in events" do
      subject.context(user_id: 123)

      expect(events_worker).to receive(:push) do |msg|
        expect(msg).not_to have_key(:user_id)
      end

      subject.event("test_event", some_data: "is here")
    end

    it "includes event-specific context in events at the root" do
      subject.event_context(user_id: 456)

      expect(events_worker).to receive(:push) do |msg|
        expect(msg[:user_id]).to eq(456)
      end

      subject.event("test_event", some_data: "is here")
    end

    it "does not merge global and event-specific context (only event context at root)" do
      subject.context(user_id: 123, global_data: "global")
      subject.event_context(user_id: 456, event_data: "event")

      expect(events_worker).to receive(:push) do |msg|
        expect(msg[:user_id]).to eq(456)
        expect(msg[:event_data]).to eq("event")
        expect(msg).not_to have_key(:global_data)
      end

      subject.event("test_event", some_data: "is here")
    end

    it "does not include event context keys when empty" do
      expect(events_worker).to receive(:push) do |msg|
        expect(msg).not_to have_key(:user_id)
        expect(msg).not_to have_key(:event_data)
      end

      subject.event("test_event", some_data: "is here")
    end

    it "clears event context when clear! is called" do
      subject.event_context(user_id: 123)
      subject.clear!

      expect(events_worker).to receive(:push) do |msg|
        expect(msg).not_to have_key(:user_id)
      end

      subject.event("test_event", some_data: "is here")
    end
  end

  context "#collect" do
    let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, debug: true, "insights.enabled": true) }
    let(:metrics_worker) { double(Honeybadger::MetricsWorker.new(config)) }
    let(:instance) { Honeybadger::Agent.new(config) }
    let(:collection_execution) { double(Honeybadger::Plugin::CollectorExecution) }

    subject { instance }

    before do
      allow(instance).to receive(:metrics_worker).and_return(metrics_worker)
    end

    context "with a collection execution instance" do
      it "adds to the worker" do
        expect(metrics_worker).to receive(:push) do |msg|
          expect(msg).to eq(collection_execution)
        end
        subject.collect(collection_execution)
      end
    end
  end
end
