require "timecop"
require "timeout"

require "honeybadger/events_worker"
require "honeybadger/config"
require "honeybadger/backend"

describe Honeybadger::EventsWorker do
  let!(:instance) { described_class.new(config) }
  let(:config) {
    Honeybadger::Config.new(
      logger: NULL_LOGGER, debug: true, backend: "null",
      "events.batch_size": 5,
      "events.timeout": 10_000
    )
  }
  let(:event) { {event_type: "test", ts: "not-important"} }

  subject { instance }

  context "when an exception happens in the worker loop" do
    before do
      allow(instance.send(:queue)).to receive(:pop).and_raise("fail")
    end

    it "does not raise when shutting down" do
      instance.push(event)

      expect { instance.shutdown }.not_to raise_error
    end

    it "exits the loop" do
      instance.push(event)
      instance.flush

      sleep(0.2)
      expect(instance.send(:thread)).not_to be_alive
    end

    it "logs the error" do
      allow(config.logger).to receive(:error)
      expect(config.logger).to receive(:error).with(/error/i)

      instance.push(event)
      instance.flush
    end
  end

  context "when an exception happens during processing" do
    before do
      allow(instance).to receive(:sleep)
      allow(instance).to receive(:handle_response).and_raise("fail")
    end

    def flush
      instance.push(event)
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
      expect(instance.send(:backend)).to receive(:event).with([event]).and_call_original
      expect(instance.push(event)).not_to eq false
      instance.flush
    end

    context "when not started" do
      before do
        allow(instance).to receive(:start).and_return false
      end

      it "rejects push" do
        expect(instance.send(:queue)).not_to receive(:push)
        expect(instance.push(event)).to eq false
      end
    end

    context "when queue is full" do
      before do
        allow(config).to receive(:events_max_queue_size).and_return(5)
        allow(instance).to receive(:queue).and_return(double(size: 5))
      end

      it "rejects the push" do
        expect(instance.send(:queue)).not_to receive(:push)
        expect(instance.push(event)).to eq false
      end
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
      expect(subject.send(:backend)).to receive(:event).with([event]).and_call_original
      subject.push(event)
      subject.shutdown
    end

    it "stops the thread" do
      subject.shutdown

      sleep(0.1)
      expect(subject.send(:thread)).not_to be_alive
    end

    context "when the server rejects data" do
      before do
        allow(subject.send(:backend)).to receive(:event).with(anything).and_return(Honeybadger::Backend::Response.new(429))
      end

      it "drops the rest of the queue" do
        expect(subject.send(:backend)).to receive(:event).exactly(1).times
        15.times { subject.push(event) }
        subject.shutdown
      end
    end
  end

  describe "#flush" do
    it "blocks until queue is flushed" do
      expect(subject.send(:backend)).to receive(:event).with([event]).and_call_original
      subject.push(event)
      subject.flush
    end
  end

  describe "#handle_response" do
    def handle_response
      instance.send(:handle_response, response)
    end

    it "only logs; the worker decides whether to suspend" do
      allow(config.logger).to receive(:warn)
      expect(instance).not_to receive(:suspend)
      instance.send(:handle_response, build_response(429, limit_reason: "rate_limited", retry_after: 30))
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

  describe "retrying" do
    let(:backend) { instance.send(:backend) }
    let(:overloaded) { build_response(429, limit_reason: "overloaded", retry_after: 30) }
    let(:success) { Honeybadger::Backend::Response.new(201) }
    let(:sends) { Queue.new }
    let(:batches) { [] }

    # Skip the 1s retry sleeps; the timeout thread's own sleep still runs.
    before do
      allow(instance).to receive(:sleep).and_call_original
      allow(instance).to receive(:sleep).with(1)
    end

    # Returns +responses+ in order, repeating the last, and records each send.
    def stub_sends(*responses)
      allow(backend).to receive(:event) do |batch|
        batches << batch.dup # the worker clears its batch after sending
        sends << true
        (responses.size > 1) ? responses.shift : responses.first
      end
    end

    # Flush skips retries, so wait for the sends to happen before flushing.
    def wait_for_sends(count)
      Timeout.timeout(3) { count.times { sends.pop } }
      instance.flush
    end

    it "resends the batch after waiting Retry-After" do
      stub_sends(overloaded, success)
      5.times { instance.push(event) }
      wait_for_sends(2)
      expected_batch = Array.new(5, event)
      expect(batches).to eq([expected_batch, expected_batch])
      expect(instance).to have_received(:sleep).with(1).exactly(30).times
    end

    it "waits 5-15 seconds when Retry-After is missing" do
      stub_sends(build_response(503), success)
      5.times { instance.push(event) }
      wait_for_sends(2)
      expect(instance).to have_received(:sleep).with(1).at_least(5).times
      expect(instance).to have_received(:sleep).with(1).at_most(15).times
    end

    it "drops the batch after MAX_RETRIES and keeps sending" do
      # Two 5-event batches: six failed sends for the first, then one success.
      first_batch_failures = Array.new(described_class::MAX_RETRIES + 1, overloaded)
      stub_sends(*first_batch_failures, success)
      10.times { instance.push(event) }
      wait_for_sends(described_class::MAX_RETRIES + 2)
      expect(backend).to have_received(:event).exactly(described_class::MAX_RETRIES + 2).times
      expect(instance.send(:start_at)).to be_nil # not suspended
    end

    it "suspends itself for the rejection's interval" do
      allow(config.logger).to receive(:warn)
      stub_sends(build_response(429, limit_reason: "rate_limited", retry_after: 30))
      5.times { instance.push(event) }
      instance.flush
      expect(instance.send(:start_at)).to be_within(1).of(Time.now.to_i + 30)
      expect(config.logger).to have_received(:warn).with(/rejecting new ones for 30s/)
    end

    it "does not wait to retry during a flush" do
      allow(instance).to receive(:sleep).with(1).and_call_original
      allow(backend).to receive(:event).and_return(overloaded)
      instance.push(event)
      Timeout.timeout(3) { instance.flush }
      expect(backend).to have_received(:event).once
    end

    it "releases every waiting flush when the worker stops" do
      gate = Queue.new
      allow(backend).to receive(:event) { gate.pop }
      5.times { instance.push(event) }
      flushers = Array.new(2) { Thread.new { instance.flush } }
      Timeout.timeout(3) { sleep(0.01) until instance.instance_variable_get(:@flushes) == 2 }
      gate << build_response(429, limit_reason: "rate_limited", retry_after: 30)
      expect(flushers.map { |t| t.join(3) }).to all(be_truthy)
      expect(instance.send(:flushing?)).to be(false)
    end

    it "does not send again after shutdown starts" do
      # Real waits, so shutdown has something to interrupt.
      allow(instance).to receive(:sleep).with(1).and_call_original
      sent = Queue.new
      allow(backend).to receive(:event) do
        sent << true
        overloaded
      end
      15.times { instance.push(event) }
      Timeout.timeout(3) { sent.pop }
      allow(config.logger).to receive(:warn)
      Timeout.timeout(3) { instance.shutdown }
      expect(backend).to have_received(:event).once
      expect(config.logger).to have_received(:warn).with(/dropping queued events/)
    end
  end

  describe "#suspend" do
    it "reports events dropped at a full queue" do
      config[:"events.max_queue_size"] = 1
      allow(instance).to receive(:start).and_return(true) # keep the pushes in the queue
      3.times { instance.push(event) }
      allow(config.logger).to receive(:warn)
      instance.send(:suspend, 60)
      expect(config.logger).to have_received(:warn).with(/Dropped 2 messages/)
    end

    it "drops the pending batch" do
      instance.send(:enqueue_msg, event)
      instance.send(:suspend, 60)
      expect(instance.send(:send_queue)).to be_empty
    end
  end

  describe "#kill!" do
    it "kills the timeout thread" do
      subject.start
      sleep(0.1)

      timeout_thread = subject.send(:timeout_thread)
      expect(timeout_thread).to be_alive

      subject.send(:kill!)
      sleep(0.1)

      expect(timeout_thread).not_to be_alive
    end

    context "when suspend is called from the worker thread" do
      before do
        allow(instance).to receive(:work) do |msg|
          instance.send(:suspend, 300)
        end
      end

      def wait_for_no_worker_threads
        50.times do
          break if Thread.list.none? { |t| t.is_a?(Honeybadger::EventsWorker::Thread) && t.alive? }
          sleep(0.1)
        end
      end

      it "kills all worker threads" do
        subject.push(event)
        wait_for_no_worker_threads

        worker_threads = Thread.list.select { |t| t.is_a?(Honeybadger::EventsWorker::Thread) && t.alive? }
        expect(worker_threads).to be_empty
      end

      it "does not leak threads across multiple suspend/restart cycles" do
        3.times do |i|
          Timecop.travel(Time.now + 301) if i > 0
          subject.push(event)
          wait_for_no_worker_threads
        end

        worker_threads = Thread.list.select { |t| t.is_a?(Honeybadger::EventsWorker::Thread) && t.alive? }
        expect(worker_threads).to be_empty
      ensure
        Timecop.return
      end
    end
  end

  describe "batching" do
    it "should send after batch size is reached" do
      expect(subject.send(:backend)).to receive(:event).with([event] * 5).and_return(Honeybadger::Backend::Null::StubbedResponse.new)
      5.times do
        subject.push(event)
      end
      sleep(0.2)
    end
    context "timeout" do
      let(:config) {
        Honeybadger::Config.new(
          logger: NULL_LOGGER, debug: true, backend: "null",
          "events.batch_size": 5,
          "events.timeout": 100
        )
      }

      it "should send after timeout when sending another" do
        expect(subject.send(:backend)).to receive(:event).with([event]).twice.and_return(Honeybadger::Backend::Null::StubbedResponse.new)
        subject.push(event)
        sleep(0.25)
        subject.push(event)
        sleep(0.25)
      end

      it "should send after timeout without new message" do
        expect(subject.send(:backend)).to receive(:event).with([event]).and_return(Honeybadger::Backend::Null::StubbedResponse.new)
        subject.push(event)
        sleep(0.25)
      end
    end
  end
end
