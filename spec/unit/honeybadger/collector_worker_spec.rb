require 'timecop'
require 'thread'

require 'honeybadger/collector_worker'
require 'honeybadger/config'

describe Honeybadger::CollectorWorker do
  let!(:instance) { described_class.new(config) }
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, :'insights.metrics' => true) }
  let(:obj) { double('CollectionExecution', tick: 1) }

  subject { instance }

  after do
    Thread.list.each do |thread|
      next unless thread.kind_of?(Honeybadger::CollectorWorker::Thread)
      Thread.kill(thread)
    end
  end

  describe "work depends on tick" do
    let(:obj) { double('CollectionExecution', tick: tick) }

    before do
      allow(instance).to receive(:sleep)
    end

    def flush
      instance.push(obj)
      instance.flush
    end

    context "when tick is not 0" do
      let(:tick) { 1 }

      it "does not call" do
        expect(obj).not_to receive(:call)
        expect(obj).not_to receive(:reset)
        flush
      end
    end

    context "when tick is 0" do
      let(:tick) { 0 }

      it "does call" do
        expect(obj).to receive(:call).at_least(:once)
        expect(obj).to receive(:reset).at_least(:once)
        flush
      end
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
    let(:obj) { double('CollectionExecution', tick: 0, call: nil, reset: nil) }

    before do
      allow(instance).to receive(:sleep)
      allow(obj).to receive(:call).and_raise('fail')
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
  end

  describe "#push" do
    it "flushes payload" do
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

  describe "#work" do
    it "enqueues after work" do
      expect(instance.send(:queue)).to receive(:push).with(obj)
      instance.send(:work, obj)
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
      subject.push(obj)
      subject.shutdown
    end

    it "stops the thread" do
      subject.shutdown

      sleep(0.1)
      expect(subject.send(:thread)).not_to be_alive
    end
  end

  describe "#flush" do
    it "blocks until queue is flushed" do
      subject.push(obj)
      subject.flush
    end
  end
end
