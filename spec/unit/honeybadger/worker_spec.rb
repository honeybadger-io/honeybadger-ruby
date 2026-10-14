require "timecop"
require "timeout"

require "honeybadger/worker"
require "honeybadger/config"
require "honeybadger/backend"
require "honeybadger/notice"

describe Honeybadger::Worker do
  let!(:instance) { described_class.new(config) }
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, backend: "null") }
  let(:obj) { double("Badger", id: :foo, to_json: "{}") }

  subject { instance }

  context "when an exception happens in the worker loop" do
    before do
      allow(instance.send(:queue)).to receive(:pop).and_raise("fail")
    end

    it "does not raise when shutting down" do
      instance.push(obj)

      expect { instance.shutdown }.not_to raise_error
    end

    it "exits the loop" do
      instance.push(obj)
      instance.flush

      sleep(0.1)
      expect(instance.send(:thread)).not_to be_alive
    end

    it "logs the error" do
      allow(config.logger).to receive(:error)
      expect(config.logger).to receive(:error).with(/error/i)

      instance.push(obj)
      instance.flush
    end
  end

  context "when an exception happens during processing" do
    before do
      allow(instance).to receive(:sleep)
      allow(instance).to receive(:handle_response).and_raise("fail")
    end

    def flush
      instance.push(obj)
      instance.flush
    end

    it "does not raise when shutting down" do
      flush
      expect { instance.shutdown }.not_to raise_error
    end

    it "does not exit the loop" do
      flush
      expect(instance.send(:thread)).to be_alive
    end

    it "logs the error" do
      allow(config.logger).to receive(:error)
      expect(config.logger).to receive(:error).with(/error/i)
      flush
    end
  end

  describe "#initialize" do
    describe "#queue" do
      subject { instance.send(:queue) }

      it { should be_a Queue }
    end

    describe "#backend" do
      subject { instance.send(:backend) }

      before do
        allow(Honeybadger::Backend::Null).to receive(:new).with(config).and_return(config.backend)
      end

      it { should be_a Honeybadger::Backend::Base }

      it "is initialized from config" do
        should eq config.backend
      end
    end
  end

  describe "#push" do
    it "flushes payload to backend" do
      expect(instance.send(:backend)).to receive(:notify).with(:notices, obj).and_call_original
      expect(instance.push(obj)).not_to eq false
      instance.flush
    end

    context "when not started" do
      before do
        allow(instance).to receive(:start).and_return false
      end

      it "rejects push" do
        expect(instance.send(:queue)).not_to receive(:push)
        expect(instance.push(obj)).to eq false
      end
    end

    context "when queue is full" do
      before do
        allow(config).to receive(:max_queue_size).and_return(5)
        allow(instance).to receive(:queue).and_return(double(size: 5))
      end

      it "rejects the push" do
        expect(instance.send(:queue)).not_to receive(:push)
        expect(instance.push(obj)).to eq false
      end

      it "warns the logger" do
        allow(config.logger).to receive(:warn)
        expect(config.logger).to receive(:warn).with(/reached max/i)
        instance.push(obj)
      end
    end
  end

  describe "#send_now" do
    let(:response) { Honeybadger::Backend::Response.new(413, %({"error":"Payload exceeds maximum size"})) }

    it "calls after_notify hooks with the notice and response" do
      hook = spy("after notify hook", arity: 2)
      config.configure { |config| config.after_notify(hook) }
      allow(instance.send(:backend)).to receive(:notify).with(:notices, obj).and_return(response)

      instance.send_now(obj)

      expect(hook).to have_received(:call).with(obj, response)
    end

    it "calls after_notify hooks for successful responses" do
      response = Honeybadger::Backend::Response.new(201)
      hook = spy("after notify hook", arity: 2)
      config.configure { |config| config.after_notify(hook) }
      allow(instance.send(:backend)).to receive(:notify).with(:notices, obj).and_return(response)

      instance.send_now(obj)

      expect(hook).to have_received(:call).with(obj, response)
    end

    it "handles the response after calling after_notify hooks" do
      config.configure do |config|
        config.after_notify { |_notice, _response| expect(instance).not_to have_received(:handle_response) }
      end
      allow(instance.send(:backend)).to receive(:notify).with(:notices, obj).and_return(response)
      allow(instance).to receive(:handle_response).and_call_original

      instance.send_now(obj)

      expect(instance).to have_received(:handle_response).with(obj, response)
    end

    it "continues processing even if an after_notify hook raises an error" do
      config.configure do |config|
        config.after_notify(->(_notice, _response) { raise ArgumentError, "bad hook" })
      end

      expect { instance.send_now(obj) }.not_to raise_error
    end

    it "logs hook errors with class and backtrace" do
      config.configure do |config|
        config.after_notify(->(_notice, _response) { raise ArgumentError, "bad hook" })
      end
      allow(config.logger).to receive(:error)

      instance.send_now(obj)

      expect(config.logger).to have_received(:error).with(/ArgumentError.*bad hook/m)
    end
  end

  describe "retrying" do
    let(:backend) { instance.send(:backend) }
    let(:overloaded) { build_response(429, limit_reason: "overloaded", retry_after: 30) }
    let(:success) { Honeybadger::Backend::Response.new(201) }
    let(:sends) { Queue.new }

    before do
      allow(instance).to receive(:sleep)
    end

    # Returns +responses+ in order, repeating the last, and records each send.
    def stub_sends(*responses)
      allow(backend).to receive(:notify) do
        sends << true
        (responses.size > 1) ? responses.shift : responses.first
      end
    end

    # Flush skips retries, so wait for the sends to happen before flushing.
    def wait_for_sends(count)
      Timeout.timeout(3) { count.times { sends.pop } }
      instance.flush
    end

    it "resends the notice after waiting Retry-After" do
      stub_sends(overloaded, success)
      instance.push(obj)
      wait_for_sends(2)
      expect(backend).to have_received(:notify).with(:notices, obj).twice
      expect(instance).to have_received(:sleep).with(1).exactly(30).times
    end

    it "waits 5-15 seconds when Retry-After is missing" do
      stub_sends(build_response(503), success)
      instance.push(obj)
      wait_for_sends(2)
      expect(instance).to have_received(:sleep).with(1).at_least(5).times
      expect(instance).to have_received(:sleep).with(1).at_most(15).times
    end

    it "fires after_notify hooks once with the final response" do
      hook = spy("after notify hook", arity: 2)
      config.configure { |config| config.after_notify(hook) }
      stub_sends(overloaded, success)
      instance.push(obj)
      wait_for_sends(2)
      expect(hook).to have_received(:call).with(obj, success).once
    end

    it "drops the notice after MAX_RETRIES and keeps sending" do
      other = double("Badger", id: :bar, to_json: "{}")
      stub_sends(*Array.new(described_class::MAX_RETRIES + 1, overloaded), success)
      instance.push(obj)
      instance.push(other)
      wait_for_sends(described_class::MAX_RETRIES + 2)
      expect(backend).to have_received(:notify).with(:notices, obj).exactly(described_class::MAX_RETRIES + 1).times
      expect(backend).to have_received(:notify).with(:notices, other).once
      expect(instance.send(:start_at)).to be_nil # not suspended
    end

    it "suspends itself for the rejection's interval" do
      allow(config.logger).to receive(:warn)
      stub_sends(build_response(429, limit_reason: "rate_limited", retry_after: 30))
      instance.push(obj)
      instance.flush
      expect(instance.send(:start_at)).to be_within(1).of(Time.now.to_i + 30)
      expect(config.logger).to have_received(:warn).with(/rejecting new ones for 30s/)
    end

    it "does not suspend when a sync send is rejected" do
      instance.start
      stub_sends(build_response(429, limit_reason: "rate_limited", retry_after: 30))
      instance.send_now(obj)
      expect(instance.send(:start_at)).to be_nil
      expect(instance.send(:thread)).to be_alive
    end

    it "does not wait to retry during a flush" do
      allow(instance).to receive(:sleep).and_call_original
      allow(backend).to receive(:notify).with(:notices, obj).and_return(overloaded)
      instance.push(obj)
      Timeout.timeout(3) { instance.flush }
      expect(backend).to have_received(:notify).with(:notices, obj).once
    end

    it "releases every waiting flush when the worker stops" do
      gate = Queue.new
      allow(backend).to receive(:notify) { gate.pop }
      instance.push(obj)
      flushers = Array.new(2) { Thread.new { instance.flush } }
      Timeout.timeout(3) { sleep(0.01) until instance.instance_variable_get(:@flushes) == 2 }
      gate << build_response(429, limit_reason: "rate_limited", retry_after: 30)
      expect(flushers.map { |t| t.join(3) }).to all(be_truthy)
      expect(instance.send(:flushing?)).to be(false)
    end

    it "does not send again after shutdown starts" do
      # Real waits, so shutdown has something to interrupt.
      allow(instance).to receive(:sleep).and_call_original
      sent = Queue.new
      allow(backend).to receive(:notify).with(:notices, obj) do
        sent << true
        overloaded
      end
      3.times { instance.push(obj) }
      Timeout.timeout(3) { sent.pop }
      Timeout.timeout(3) { instance.shutdown }
      expect(backend).to have_received(:notify).with(:notices, obj).once
    end
  end

  describe "#start" do
    it "starts the thread" do
      expect { subject.start }.to change(subject, :thread).to(kind_of(Thread))
    end

    it "changes the pid to the current pid" do
      allow(Process).to receive(:pid).and_return(:expected)
      expect { subject.start }.to change(subject, :pid).to(:expected)
    end

    context "when shutdown" do
      before do
        subject.shutdown
      end

      it "doesn't start" do
        expect { subject.start }.not_to change(subject, :thread)
      end
    end

    context "when suspended" do
      before do
        subject.send(:suspend, 300)
      end

      context "and restart is in the future" do
        it "doesn't start" do
          expect { subject.start }.not_to change(subject, :thread)
        end
      end

      context "and restart is in the past" do
        it "starts the thread" do
          Timecop.travel(Time.now + 301) do
            expect { subject.start }.to change(subject, :thread).to(kind_of(Thread))
          end
        end
      end
    end
  end

  describe "#shutdown" do
    before { subject.start }

    it "blocks until queue is processed" do
      expect(subject.send(:backend)).to receive(:notify).with(kind_of(Symbol), obj).and_call_original
      subject.push(obj)
      subject.shutdown
    end

    it "stops the thread" do
      subject.shutdown

      sleep(0.1)
      expect(subject.send(:thread)).not_to be_alive
    end

    context "when the server rejects data" do
      before do
        allow(subject.send(:backend)).to receive(:notify).with(:notices, obj).and_return(Honeybadger::Backend::Response.new(429))
      end

      it "drops the rest of the queue" do
        expect(subject.send(:backend)).to receive(:notify).exactly(1).times
        5.times { subject.push(obj) }
        subject.shutdown
      end
    end
  end

  describe "#flush" do
    it "blocks until queue is flushed" do
      expect(subject.send(:backend)).to receive(:notify).with(kind_of(Symbol), obj).and_call_original
      subject.push(obj)
      subject.flush
    end
  end

  describe "#signal_flush_done" do
    it "does not cause deadlock when called from within a synchronized block" do
      # This test verifies that the JRuby deadlock issue is fixed
      # The original issue was that signal_flush_done would try to acquire
      # a mutex that was already owned by the same thread, causing a deadlock

      subject.start

      # Call signal_flush_done from within a synchronized block
      # This should not cause a deadlock
      expect {
        subject.send(:mutex).synchronize do
          subject.send(:signal_flush_done)
        end
      }.not_to raise_error
    end

    it "signals immediately without thread overhead" do
      # This test verifies that signal_flush_done executes immediately
      # and doesn't create unnecessary threads

      subject.start
      initial_thread_count = Thread.list.count

      # Call signal_flush_done and verify it executes immediately
      expect {
        subject.send(:signal_flush_done)
      }.not_to raise_error

      # Verify no new threads were created
      expect(Thread.list.count).to eq(initial_thread_count)
    end
  end

  describe "#handle_response" do
    def handle_response
      instance.send(:handle_response, obj, response)
    end

    it "only logs; the worker decides whether to suspend" do
      allow(config.logger).to receive(:warn)
      expect(instance).not_to receive(:suspend)
      instance.send(:handle_response, obj, build_response(429, limit_reason: "rate_limited", retry_after: 30))
    end

    context "when 429 is rate-limited" do
      let(:response) { build_response(429, limit_reason: "rate_limited", retry_after: 30) }

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/server is rejecting data/)
        handle_response
      end
    end

    context "when retryable" do
      let(:response) { build_response(503) }

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/unavailable/)
        handle_response
      end
    end

    context "when 403" do
      let(:response) { Honeybadger::Backend::Response.new(403, %({"error":"unauthorized"})) }

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/unauthorized/)
        handle_response
      end
    end

    context "when 413" do
      let(:response) { Honeybadger::Backend::Response.new(413, %({"error":"Payload exceeds maximum size"})) }

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/too large/)
        handle_response
      end
    end

    context "when 201" do
      let(:response) { Honeybadger::Backend::Response.new(201) }

      it "doesn't warn" do
        expect(config.logger).not_to receive(:warn)
        handle_response
      end
    end

    context "when unknown" do
      let(:response) { Honeybadger::Backend::Response.new(418) }

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/failed/)
        handle_response
      end
    end

    context "when error" do
      let(:response) { Honeybadger::Backend::Response.new(:error, nil, "test error message") }

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/test error message/)
        handle_response
      end
    end

    context "when stubbed" do
      let(:response) { Honeybadger::Backend::Response.new(:stubbed) }

      it "logs at debug level" do
        allow(config.logger).to receive(:debug)
        allow(config.logger).to receive(:info)
        handle_response
        expect(config.logger).to have_received(:debug).with(/Development mode is enabled/)
        expect(config.logger).not_to have_received(:info)
      end
    end
  end
end
