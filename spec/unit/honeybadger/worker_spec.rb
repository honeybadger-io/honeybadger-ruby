require 'timecop'
require 'thread'

require 'honeybadger/worker'
require 'honeybadger/config'
require 'honeybadger/backend'
require 'honeybadger/notice'

describe Honeybadger::Worker do
  let(:instance) { described_class.new(config) }
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
      instance.push(obj)
      instance.flush
      sleep(0.05)
    end

    it "does not raise when shutting down" do
      expect { instance.shutdown }.not_to raise_error
    end

    it "exits the loop" do
      expect(instance.send(:thread)).not_to be_alive
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

    it "sleeps for a short period" do
      expect(instance).to receive(:sleep).with(1..5)
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
  end

  describe "#start" do
    it "starts the thread" do
      expect { subject.start }.to change(subject, :thread).to(kind_of(Thread))
    end

    it "changes the pid to the current pid" do
      allow(Process).to receive(:pid).and_return(101)
      expect { subject.start }.to change(subject, :pid).to(101)
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

    it "stops the thread" do
      subject.shutdown
      expect(subject.send(:thread)).not_to be_alive
    end

    it "clears the pid" do
      expect { subject.shutdown }.to change(subject, :pid).to(nil)
    end
  end

  describe "#shutdown!" do
    before { subject.start }

    it "kills the thread" do
      subject.shutdown!
      expect(subject.send(:thread)).not_to be_alive
    end

    it "logs debug info" do
      allow(config.logger).to receive(:debug)
      expect(config.logger).to receive(:debug).with(/kill/i)
      subject.shutdown!
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
