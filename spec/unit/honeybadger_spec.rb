require 'honeybadger/ruby'

RSpec::Matchers.define :define do |expected|
  match do |actual|
    expect(actual.constants).to include(expected)
  end
end

describe Honeybadger do
  it { should be_a Module }
  it { should respond_to :notify }
  it { should respond_to :start }
  it { should respond_to :track_deployment }

  it { should define(:Rack) }

  describe Honeybadger::Rack do
    it { should define(:ErrorNotifier) }
    it { should define(:UserFeedback) }
    it { should define(:UserInformer) }
  end

  it "delegates ::exception_filter to agent config" do
    expect(Honeybadger.config).to receive(:exception_filter)
    Honeybadger.exception_filter {}
  end

  it "delegates ::backtrace_filter to agent config" do
    expect(Honeybadger.config).to receive(:backtrace_filter)
    Honeybadger.backtrace_filter {}
  end

  it "delegates ::exception_fingerprint to agent config" do
    expect(Honeybadger.config).to receive(:exception_fingerprint)
    Honeybadger.exception_fingerprint {}
  end

  it "delegates ::flush to agent instance" do
    expect(Honeybadger::Agent.instance).to receive(:flush)
    Honeybadger.flush
  end

  describe "#context" do
    let(:c) { {foo: :bar} }

    before { described_class.context(c) }

    it "sets the context" do
      described_class.context(c)
    end

    it "merges existing context" do
      described_class.context({bar: :baz})
      expect(described_class.get_context).to eq({foo: :bar, bar: :baz})
    end

    it "gets current context" do
      expect(described_class.get_context).to eq(c)
    end

    it "clears the context" do
      expect { described_class.context.clear! }.to change { described_class.get_context }.from(c).to(nil)
    end
  end

  describe "#notify" do
    let(:config) { Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER) }
    let(:instance) { Honeybadger::Agent.new(config) }
    let(:worker) { double('Honeybadger::Worker') }

    before do
      allow(Honeybadger::Agent).to receive(:instance).and_return(instance)
      allow(instance).to receive(:worker).and_return(worker)
    end

    it "creates and send a notice for an exception" do
      exception = build_exception
      notice = stub_notice!(config)

      expect(Honeybadger::Notice).to receive(:new).with(config, hash_including(exception: exception)).and_return(notice)
      expect(worker).to receive(:push).with(notice)

      Honeybadger.notify(exception)
    end

    it "creates and send a notice for a hash" do
      exception = build_exception
      notice = stub_notice!(config)

      expect(Honeybadger::Notice).to receive(:new).with(config, hash_including(error_message: 'uh oh')).and_return(notice)
      expect(worker).to receive(:push).with(notice)

      Honeybadger.notify(error_message: 'uh oh')
    end

    it "does not pass the hash as an exception when sending a notice for it" do
      notice = stub_notice!(config)

      expect(Honeybadger::Notice).to receive(:new).with(anything, hash_excluding(:exception))
      expect(worker).to receive(:push).with(notice)

      Honeybadger.notify(error_message: 'uh oh')
    end

    it "creates and sends a notice for an exception and hash" do
      exception = build_exception
      notice = stub_notice!(config)
      notice_args = { error_message: 'uh oh' }

      expect(Honeybadger::Notice).to receive(:new).with(config, hash_including(notice_args.merge(exception: exception))).and_return(notice)
      expect(worker).to receive(:push).with(notice)

      Honeybadger.notify(exception, notice_args)
    end

    it "sends a notice with a string" do
      notice = stub_notice!(config)

      expect(Honeybadger::Notice).to receive(:new).with(config, hash_including(error_message: 'the test message')).and_return(notice)
      expect(worker).to receive(:push).with(notice)

      Honeybadger.notify('the test message')
    end

    it "sends a notice with any arbitrary object" do
      notice = stub_notice!(config)

      expect(Honeybadger::Notice).to receive(:new).with(config, hash_including(error_message: 'the test message')).and_return(notice)
      expect(worker).to receive(:push).with(notice)

      Honeybadger.notify(double(to_s: 'the test message'))
    end

    it "generates a backtrace excluding the singleton" do
      expect(instance.worker).to receive(:push) do |notice|
        expect(notice.backtrace.to_a[0]).to match('lib/honeybadger/agent.rb')
      end

      Honeybadger.notify(error_message: 'testing backtrace generation')
    end

    it "does not deliver an ignored exception when notifying implicitly" do
      exception = build_exception
      notice = stub_notice!(config)
      allow(notice).to receive(:ignore?).and_return(true)

      expect(worker).not_to receive(:push)

      Honeybadger.notify(exception)
    end

    it "does not deliver a halted notice when notifying implicitly" do
      exception = build_exception
      notice = stub_notice!(config)
      allow(notice).to receive(:halted?).and_return(true)

      expect(worker).not_to receive(:push)

      Honeybadger.notify(exception)
    end

    it "does not deliver a halted notice when notifying implicitly with :force option" do
      exception = build_exception
      notice = stub_notice!(config)
      allow(notice).to receive(:halted?).and_return(true)

      expect(worker).not_to receive(:push)

      Honeybadger.notify(exception, force: true)
    end

    it "delivers an ignored exception when notifying implicitly with :force option" do
      exception = build_exception
      notice = stub_notice!(config)
      allow(notice).to receive(:ignore?).and_return(true)

      expect(worker).to receive(:push)

      Honeybadger.notify(exception, force: true)
    end

    it "passes config to created notices" do
      exception = build_exception
      config_opts = { 'one' => 'two', 'three' => 'four' }

      notice = stub_notice(config)

      allow(worker).to receive(:push)
      expect(Honeybadger::Notice).to receive(:new).with(config, kind_of(Hash)).and_return(notice)

      Honeybadger.notify(exception)
    end

    context "without minimum options" do
      context "outside development" do
        it "it warns the logger" do
          expect(worker).to receive(:push)
          expect(Honeybadger.config.logger).to receive(:warn).with(/invalid arguments/)
          Honeybadger.notify({})
        end
      end

      context "in development" do
        it "raises an exception" do
          allow(Honeybadger.config).to receive(:dev?).and_return(true)
          expect(worker).not_to receive(:push)
          expect(Honeybadger.config.logger).not_to receive(:warn)
          expect { Honeybadger.notify({}) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "#configure" do
    before do
      Honeybadger.config.set(:api_key, nil)
      Honeybadger.config.set(:'user_informer.enabled', true)
    end

    it "configures the singleton" do
      expect {
        Honeybadger.configure do |config|
          config.api_key = 'test api key'
        end
      }.to change { Honeybadger.config.get(:api_key) }.from(nil).to('test api key')
    end

    it "yields a Ruby config object" do
      Honeybadger.configure do |config|
        expect(config).to be_a(Honeybadger::Config::Ruby)
      end
    end
  end
end
