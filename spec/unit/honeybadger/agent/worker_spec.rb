require 'timecop'
require 'thread'

require 'honeybadger/agent/worker'
require 'honeybadger/config'
require 'honeybadger/backend'
require 'honeybadger/notice'

describe Honeybadger::Agent::NullWorker do
  Honeybadger::Agent::Worker.instance_methods.each do |method|
    it "responds to #{method}" do
      expect(subject).to respond_to(method)
      expect(subject.method(method).arity).to eq Honeybadger::Agent::Worker.instance_method(method).arity
    end
  end
end

describe Honeybadger::Agent::Worker do
  let(:instance) { described_class.new(config, feature) }
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, backend: 'null') }
  let(:feature) { :badgers }
  let(:obj) { double('Badger', id: :foo, to_json: '{}') }

  subject { instance }

  after { instance.shutdown! }

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
      expect(instance.send(:backend)).to receive(:notify).with(feature, obj).and_call_original
      instance.push(obj)
      instance.flush
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
  end

  describe "#shutdown" do
    before { subject.start }

    it "stops the thread" do
      expect { subject.shutdown }.to change(subject, :thread).to(nil)
    end

    it "clears the pid" do
      expect { subject.shutdown }.to change(subject, :pid).to(nil)
    end

    context "with an optional timeout" do
      it "kills the thread" do
        expect { subject.shutdown(0); subject.send(:thread).join(1) }.to change(subject, :thread).to(nil)
      end

      it "logs debug info" do
        allow(config.logger).to receive(:debug)
        expect(config.logger).to receive(:debug).with(/kill/i)
        subject.shutdown(0)
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
end
