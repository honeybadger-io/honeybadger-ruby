require 'timecop'

require 'honeybadger/worker'
require 'honeybadger/config'
require 'honeybadger/backend'
require 'honeybadger/notice'

describe Honeybadger::Worker do
  let(:instance) { Honeybadger::Worker.new(config) }
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }
  let(:enable_thread) { false }

  subject { instance }

  before do
    allow(Thread).to receive(:new) do
      double('Thread', :join => true, :[] => true, :[]= => true)
    end
  end

  describe "#initialize" do
    describe "#metrics" do
      subject { instance.metrics }

      it { should be_a Honeybadger::Worker::MetricsCollector }
    end

    describe "#traces" do
      subject { instance.traces }

      it { should be_a Honeybadger::Worker::Batch }
    end

    describe "#queue" do
      subject { instance.queue }

      it { should be_a Hash }

      it "initializes a queue for each feature" do
        expect(subject[:notices]).to be_a Honeybadger::Worker::MeteredQueue
        expect(subject[:metrics]).to be_a Honeybadger::Worker::MeteredQueue
        expect(subject[:traces]).to be_a Honeybadger::Worker::MeteredQueue
      end
    end

    describe "#backend" do
      subject { instance.backend }

      before do
        allow(Honeybadger::Backend::Server).to receive(:new).with(config).and_return(config.backend)
      end

      it { should be_a Honeybadger::Backend::Base }

      it "is initialized from config" do
        should eq config.backend
      end
    end
  end

  describe "#start" do
    after { subject.stop }

    it "starts the thread" do
      expect { subject.start }.to change(subject, :thread).to(kind_of(RSpec::Mocks::Double))
    end

    it "changes the pid to the current pid" do
      allow(Process).to receive(:pid).and_return(101)
      expect { subject.start }.to change(subject, :pid).to(101)
    end
  end

  describe "#stop" do
    before { subject.start }

    it "stops the thread" do
      expect { subject.stop }.to change(subject, :thread).to(nil)
    end

    it "clears the pid" do
      expect { subject.stop }.to change(subject, :pid).to(nil)
    end

    context "with optional argument of true" do
      before do
        expect(Thread).to receive(:kill).with(subject.thread)
      end

      it "kills the thread" do
        expect { subject.stop(true) }.to change(subject, :thread).to(nil)
      end

      it "logs debug info" do
        allow(config.logger).to receive(:debug)
        expect(config.logger).to receive(:debug).with(/kill/i)
        subject.stop(true)
      end
    end
  end

  describe "#fork" do
    before { subject.start }
    after { subject.stop }

    it "logs debug information" do
      allow(config.logger).to receive(:debug)
      expect(config.logger).to receive(:debug).with(/forking/i)
      subject.fork
    end

    it "restarts the worker thread" do
      old_thread = instance.thread
      subject.fork
      expect(instance.thread).not_to be old_thread
      expect(instance.thread).to be_a RSpec::Mocks::Double
    end

    it "unlocks the mutex first" do
      instance.mutex.lock
      expect { subject.fork }.not_to raise_error
    end
  end

  describe "#trace" do
    let(:trace) { double('Trace', duration: duration, id: :foo, to_h: {}) }

    context "when the duration exceeds threshold" do
      let(:duration) { 8000 }

      it "logs debug info" do
        expect(config.logger).to receive(:debug).with(/foo/i)
        subject.trace(trace)
      end

      it "adds trace to batch" do
        expect { subject.trace(trace) }.to change(subject.traces, :size).by(1)
      end
    end

    context "when the trace duration is less than threshold" do
      let(:duration) { 500 }

      it "does not add trace to batch" do
        expect { subject.trace(trace) }.not_to change(subject.traces, :size)
      end

      it "logs debug info" do
        expect(config.logger).to receive(:debug).with(/foo/i)
        subject.trace(trace)
      end
    end
  end

  describe "#timing" do
    it "adds metrics to collector" do
      expect { instance.timing('foo', 5) }.to change(instance.metrics[:timing], :size).by(1)
    end
  end

  describe "#increment" do
    it "adds metrics to collector" do
      expect { instance.increment('foo', 5) }.to change(instance.metrics[:counter], :size).by(1)
    end
  end

  describe "#run" do
    before do
      # Allow one work cycle before exiting
      allow(instance).to receive(:finish).and_return(false, true)
    end

    it "logs debug info" do
      allow(config.logger).to receive(:debug)
      expect(config.logger).to receive(:debug).with(/start/i)
      instance.send(:run)
    end

    it "sends notices to backend" do
      stub_http

      notice = double('Notice', id: :foo, to_json: '{}')
      instance.notice(notice)

      expect(instance.backend).to receive(:notify).with(:notices, notice).and_call_original

      Timecop.travel(Time.now + 1000) do
        instance.send(:run)
      end
    end

    it "sends traces to backend" do
      stub_http

      trace = double('Trace', duration: 8000, id: :foo, to_h: {})
      instance.trace(trace)

      expect(instance.backend).to receive(:notify).with(:traces, kind_of(Honeybadger::Worker::Batch)).and_call_original

      Timecop.travel(Time.now + 1000) do
        instance.send(:run)
      end
    end

    it "sends metrics to backend" do
      stub_http

      instance.timing('foo', 5)

      expect(instance.backend).to receive(:notify).with(:metrics, kind_of(Honeybadger::Worker::MetricsCollector::Chunk)).and_call_original

      Timecop.travel(Time.now + 1000) do
        instance.send(:run)
      end
    end

    context "when an exception occurs" do
      before do
        allow(instance).to receive(:work).and_raise(RuntimeError.new('snakes!'))
      end

      it "logs error info" do
        expect(config.logger).to receive(:error).with(/snakes/i)
        expect { instance.send(:run) }.to raise_error
      end

      it "re-raises errors to caller" do
        expect { instance.send(:run) }.to raise_error
      end
    end
  end

  describe "#work" do
    subject { instance.send(:work) }

    before do
      allow(instance).to receive(:sleep)
    end

    context "when an exception occurs" do
      let(:queue) { instance.queue[:notices] }

      before do
        allow(queue).to receive(:pop).and_raise(RuntimeError.new('snakes!'))
      end

      it "logs error info" do
        expect(config.logger).to receive(:error).with(/snakes/i)
        instance.send(:work)
      end

      it "does not re-raise errors to caller" do
        expect { instance.send(:work) }.not_to raise_error
      end

      it "sleeps for a short duration" do
        expect(instance).to receive(:sleep).with(0.5..5)
        instance.send(:work)
      end
    end
  end

  describe "#finish" do
    subject { instance.send(:finish) }

    context "when thread is working" do
      it { should be_nil }
    end

    context "when thread is exiting" do
      around do |example|
        Thread.current[:should_exit] = true

        begin
          example.run
        ensure
          Thread.current[:should_exit] = nil
        end
      end

      it { should eq true }

      it "flushes notices to backend" do
        stub_http

        notice = double('Notice', id: :foo, to_json: '{}')
        instance.notice(notice)

        expect(instance.backend).to receive(:notify).with(:notices, notice).and_call_original

        Timecop.travel(Time.now + 1000) do
          instance.send(:finish)
        end
      end

      it "flushes traces to backend" do
        stub_http

        trace = double('Trace', duration: 8000, id: :foo, to_h: {})
        instance.trace(trace)

        expect(instance.backend).to receive(:notify).with(:traces, kind_of(Honeybadger::Worker::Batch)).and_call_original

        Timecop.travel(Time.now + 1000) do
          instance.send(:finish)
        end
      end
    end
  end
end
