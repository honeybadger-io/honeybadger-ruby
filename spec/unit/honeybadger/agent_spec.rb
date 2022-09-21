require 'honeybadger/agent'
require 'timecop'

describe Honeybadger::Agent do
  NULL_BLOCK = Proc.new{}.freeze

  describe "class methods" do
    subject { described_class }

    its(:instance) { should be_a(Honeybadger::Agent) }
  end

  describe "#check_in" do
    it 'parses check_in id from a url' do
      stub_request(:get, "https://api.honeybadger.io/v1/check_in/1MqIo1").
         to_return(status: 200)

      config = Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER)
      instance = described_class.new(config)

      instance.check_in('https://api.honeybadger.io/v1/check_in/1MqIo1')
    end

    it 'returns true for successful check ins' do
      stub_request(:get, "https://api.honeybadger.io/v1/check_in/foobar").
         to_return(status: 200)

      config = Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER)
      instance = described_class.new(config)

      expect(instance.check_in('foobar')).to eq(true)
      expect(instance.check_in('/foobar')).to eq(true)
      expect(instance.check_in('/foobar/')).to eq(true)
    end

    it 'returns false for failed check ins' do
      stub_request(:get, "https://api.honeybadger.io/v1/check_in/danny").
         to_return(status: 400)

      config = Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER)
      instance = described_class.new(config)

      expect(instance.check_in('danny')).to eq(false)
    end
  end

  describe '#track_deployment' do
    let(:config) { Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER) }
    subject(:instance) { described_class.new(config) }

    it 'returns true for successful deployment tracking' do
      stub_request(:post, "https://api.honeybadger.io/v1/deploys").
         to_return(status: 200)

      expect(instance.track_deployment).to eq(true)
    end

    it 'returns false for unsuccessful deployment tracking' do
      stub_request(:post, "https://api.honeybadger.io/v1/deploys").
         to_return(status: 400)

      expect(instance.track_deployment).to eq(false)
    end

    it 'passes the revision to the servce' do
      allow_any_instance_of(Honeybadger::Util::HTTP).to receive(:compress) { |_, body| body }
      stub_request(:post, "https://api.honeybadger.io/v1/deploys").
         with(body: { environment: nil, revision: '1234', local_username: nil, repository: nil }).
         to_return(status: 200)

      expect(instance.track_deployment(revision: '1234')).to eq(true)
    end
  end

  describe "#clear!" do
    it 'clears all transactional data' do
      config = Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER)
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
      config = Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER)
      instance = described_class.new(config)

      expect(instance.worker).to receive(:push) do |notice|
        expect(notice.backtrace.to_a[0]).to match('lib/honeybadger/agent.rb')
      end

      instance.notify(error_message: 'testing backtrace generation')
    end

    it "does not mutate passed in opts" do
      opts = {error_message: 'test'}
      prev = opts.dup
      instance = described_class.new(Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER))
      instance.notify("test", opts)
      expect(prev).to eq(opts)
    end

    it "does not report an already reported exception" do
      instance = described_class.new(Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER))
      exception = RuntimeError.new
      exception.instance_variable_set(:@__hb_handled, true)
      expect(instance.notify(exception)).to be_nil
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
      let(:config) { Honeybadger::Config.new(api_key: "fake api key", logger: NULL_LOGGER, :'breadcrumbs.enabled' => true) }

      subject { described_class.new(config) }

      it "stores notice breadcrumb and passes along duplicated breadcrumbs" do
        duped_breadcrumbs = double(each: [])
        expect(subject).to receive(:breadcrumbs).and_return(breadcrumbs)
        expect(subject).to receive(:add_breadcrumb).with(
          "Honeybadger Notice",
          metadata: { error_message: "passed breadcrumbs?" },
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
    let(:config) { Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER) }
    subject { described_class.new(config) }

    before do
      Thread.current[:__hb_breadcrumbs] = nil
    end

    describe "#breadcrumbs" do
      context 'when local_context: true' do
        let(:config) { { local_context: true } }

        it 'creates instance local breadcrumb' do
          subject.breadcrumbs
          expect(Thread.current[:__hb_breadcrumbs]).to be nil
        end

        it 'instantiates the breadcrumb collector with the right config' do
          allow(Honeybadger::Breadcrumbs::Collector).to receive(:new).and_call_original
          subject.breadcrumbs
          expect(Honeybadger::Breadcrumbs::Collector).to have_received(:new).with(instance_of(Honeybadger::Config))
        end
      end

      it 'stores breadcrumbs in thread local' do
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

      it 'has sane defaults' do
        crumb = Honeybadger::Breadcrumbs::Breadcrumb.new(category: "custom", message: "Basic Message", metadata: {})
        expect(breadcrumbs).to receive(:add!).with(crumb)

        subject.add_breadcrumb("Basic Message")
      end

      it 'sanitizes breadcrumb before adding' do
        sanitizer = instance_double(Honeybadger::Util::Sanitizer)
        allow(breadcrumbs).to receive(:add!)
        expect(Honeybadger::Util::Sanitizer).to receive(:new).with(max_depth: 2).and_return(sanitizer)
        expect(sanitizer).to receive(:sanitize).with(hash_including({message: "Breadcrumb"})).and_return({})
        expect(Honeybadger::Breadcrumbs::Breadcrumb).to receive(:new)

        subject.add_breadcrumb("Breadcrumb")
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
        let(:block) { Proc.new { expecting.call } }
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
        let(:block) { Proc.new { fail 'oops' } }

        it "flushes worker" do
          expect(instance.worker).to receive(:flush)
          expect { subject }.to raise_error /oops/
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
end
