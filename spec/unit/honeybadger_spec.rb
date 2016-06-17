require 'honeybadger'

RSpec::Matchers.define :define do |expected|
  match do |actual|
    expect(actual.constants).to include(expected)
  end
end

describe Honeybadger do
  it { should be_a Module }
  it { should respond_to :notify }
  it { should respond_to :start }

  it { should define(:Rack) }

  describe Honeybadger::Rack do
    it { should define(:ErrorNotifier) }
    it { should define(:UserFeedback) }
    it { should define(:UserInformer) }
  end

  describe "delegated methods" do
    method_and_args = {
      start: nil,
      stop: nil,
      exception_filter: nil,
      exception_fingerprint: nil,
      backtrace_filter: nil,
      flush: nil
    }

    method_and_args.keys.each do |method|
      it "delegates ##{method} to Agent" do
        args = Array(method_and_args[method])

        if args.any?
          expect(Honeybadger::Agent).to receive(method).with(*args)
        else
          expect(Honeybadger::Agent).to receive(method)
        end

        described_class.send(method, *args)
      end
    end
  end

  describe "#context" do
    let(:c) { {foo: :bar} }

    before { described_class.context(c) }

    it "sets the context" do
      described_class.context(c)
    end

    it "merges existing context" do
      described_class.context({bar: :baz})
      expect(Thread.current[:__honeybadger_context]).to eq({foo: :bar, bar: :baz})
    end

    it "gets current context" do
      expect(described_class.get_context).to eq(c)
    end

    it "clears the context" do
      expect { described_class.context.clear! }.to change { Thread.current[:__honeybadger_context] }.from(c).to(nil)
    end
  end

  describe "#notify" do
    let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER) }
    let(:instance) { Honeybadger::Agent.new(config) }
    let(:worker) { double('Honeybadger::Worker') }

    before do
      allow(Honeybadger::Agent).to receive(:instance).and_return(instance)
      allow(instance).to receive(:workers).and_return({notices: worker})
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
      notice = stub_notice!

      expect(Honeybadger::Notice).to receive(:new).with(anything, hash_excluding(:exception))
      expect(worker).to receive(:push).with(notice)

      Honeybadger.notify(error_message: 'uh oh')
    end

    it "creates and sends a notice for an exception and hash" do
      exception = build_exception
      notice = stub_notice!
      notice_args = { error_message: 'uh oh' }

      expect(Honeybadger::Notice).to receive(:new).with(config, hash_including(notice_args.merge(exception: exception))).and_return(notice)
      expect(worker).to receive(:push).with(notice)

      Honeybadger.notify(exception, notice_args)
    end

    it "does not deliver an ignored exception when notifying implicitly" do
      exception = build_exception
      notice = stub_notice!
      allow(notice).to receive(:ignore?).and_return(true)

      expect(worker).not_to receive(:push)

      Honeybadger.notify(exception)
    end

    it "delivers an ignored exception when notifying implicitly with :force option" do
      exception = build_exception
      notice = stub_notice!
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
  end

  describe "#configure" do
    it "warns that an upgrade is required" do
      expect(Honeybadger).to receive(:warn).with(/upgrade/)
      Honeybadger.configure do |config|
        config.api_key = 'asdf'
      end
    end
  end
end
