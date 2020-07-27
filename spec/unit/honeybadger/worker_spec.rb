require 'timecop'
require 'thread'

require 'honeybadger/worker'
require 'honeybadger/config'
require 'honeybadger/backend'
require 'honeybadger/notice'

describe Honeybadger::Worker do
  let!(:instance) { described_class.new(config) }
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, backend: 'null') }
  let(:obj) { double('Badger', id: :foo, to_json: '{}') }

  subject { instance }

  after do
    Thread.list.each do |thread|
      next unless thread.kind_of?(Honeybadger::Worker::Thread)
      Thread.kill(thread)
    end
  end

  context "when an exception happens in the worker loop" do
    before do
      allow(instance.send(:queue)).to receive(:pop).and_raise('fail')
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
      allow(instance).to receive(:handle_response).and_raise('fail')
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

    context "when previously throttled" do
      before do
        100.times { subject.send(:inc_throttle) }
        subject.push(obj)
        sleep(0.01) # Pause to allow throttle to activate
      end

      it "shuts down immediately" do
        expect(subject.send(:backend)).not_to receive(:notify)
        subject.push(obj)
        subject.shutdown
      end

      it "does not warn the logger when the queue is empty" do
        allow(config.logger).to receive(:warn)
        expect(config.logger).not_to receive(:warn)
        subject.shutdown
      end

      it "warns the logger when queue has items" do
        subject.push(obj)
        allow(config.logger).to receive(:warn)
        expect(config.logger).to receive(:warn).with(/throttled/i)
        subject.shutdown
      end
    end

    context "when throttled during shutdown" do
      before do
        allow(subject.send(:backend)).to receive(:notify).with(:notices, obj).and_return(Honeybadger::Backend::Response.new(429) )
      end

      it "shuts down immediately" do
        expect(subject.send(:backend)).to receive(:notify).exactly(1).times
        5.times { subject.push(obj) }
        subject.shutdown
      end

      it "does not warn the logger when the queue is empty" do
        allow(config.logger).to receive(:warn)
        expect(config.logger).not_to receive(:warn).with(/throttled/)

        subject.push(obj)
        subject.shutdown
      end

      it "warns the logger when the queue has additional items" do
        allow(config.logger).to receive(:warn)
        expect(config.logger).to receive(:warn).with(/throttled/i)

        30.times do
          subject.push(obj)
        end

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

  describe "#handle_response" do
    def handle_response
      instance.send(:handle_response, obj, response)
    end

    before do
      allow(instance).to receive(:suspend).and_return true
    end

    context "when 429" do
      let(:response) { Honeybadger::Backend::Response.new(429) }

      it "adds throttle" do
        expect { handle_response }.to change(instance, :throttle_interval).by(0.05)
      end
    end

    context "when 402" do
      let(:response) { Honeybadger::Backend::Response.new(402) }

      it "shuts down the worker" do
        expect(instance).to receive(:suspend)
        handle_response
      end

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/payment/)
        handle_response
      end
    end

    context "when 403" do
      let(:response) { Honeybadger::Backend::Response.new(403, %({"error":"unauthorized"})) }

      it "shuts down the worker" do
        expect(instance).to receive(:suspend)
        handle_response
      end

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/invalid/)
        handle_response
      end
    end

    context "when 201" do
      let(:response) { Honeybadger::Backend::Response.new(201) }

      context "and there is no throttle" do
        it "doesn't change throttle" do
          expect { handle_response }.not_to change(instance, :throttle_interval)
        end
      end

      context "and a throttle is set" do
        before { instance.send(:inc_throttle) }

        it "removes throttle" do
          expect { handle_response }.to change(instance, :throttle_interval).by(-0.05)
        end
      end

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
      let(:response) { Honeybadger::Backend::Response.new(:error, nil, 'test error message') }

      it "warns the logger" do
        expect(config.logger).to receive(:warn).with(/test error message/)
        handle_response
      end
    end
  end
end
