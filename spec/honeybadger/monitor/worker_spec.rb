require 'spec_helper'
require 'honeybadger/monitor'

describe Honeybadger::Monitor::Worker do
  let(:instance) { Honeybadger::Monitor::Worker.send(:new) }
  subject { instance }

  before(:each) do
    Thread.stub(:new)

    # Create attr_readers for testing values
    instance.stub(:metrics) { instance.instance_variable_get(:@metrics) }
    instance.stub(:traces) { instance.instance_variable_get(:@traces) }
    instance.stub(:sender) { instance.instance_variable_get(:@sender) }
    instance.stub(:thread) { instance.instance_variable_get(:@thread) }
    instance.stub(:lock) { instance.instance_variable_get(:@lock) }
  end

  describe "#queue_trace" do
    let(:trace) { Honeybadger::Monitor::Trace.new(:foo) }

    context "when a trace exists" do
      before do
        trace.stub(:key).and_return(:bar)
        subject.pending_traces[:foo] = trace
        Thread.current[:hb_trace_id] = :foo
      end

      context "and the same trace key exists" do
        let(:old_trace) { Honeybadger::Monitor::Trace.new(:foo) }

        before do
          old_trace.stub(:duration).and_return(2000)
          old_trace.stub(:key).and_return(:bar)
          subject.traces[:bar] = old_trace
        end

        context "and the new duration is not greater" do
          before { trace.stub(:duration).and_return(2000) }

          it "replaces the existing trace" do
            expect { subject.queue_trace }.not_to change { subject.traces[:bar] }.from(old_trace)
          end
        end

        context "and the new duration is greater" do
          before { trace.stub(:duration).and_return(3000) }

          it "replaces the existing trace" do
            expect { subject.queue_trace }.to change { subject.traces[:bar] }.from(old_trace).to(trace)
          end
        end
      end
    end
  end

  describe "#fork" do
    before { Thread.unstub(:new) }
    before { Honeybadger.stub(:write_verbose_log) }
    before { subject.start }
    after { subject.stop }

    it "logs debug information" do
      Honeybadger.should_receive(:write_verbose_log).with(/forking/i)
      subject.fork
    end

    it "restarts the worker thread" do
      old_thread = instance.thread
      subject.fork
      expect(instance.thread).not_to be old_thread
    end

    it "unlocks the mutex first" do
      instance.lock.lock
      expect { subject.fork }.not_to raise_error
    end
  end

  describe '#initialize' do
    describe '@metrics' do
      subject { instance.instance_variable_get(:@metrics) }

      it { should have_key(:timing) }
      it { should have_key(:counter) }

      it 'is initialized timing with empty hash' do
        expect(subject[:timing]).to eq({})
      end

      it 'is initialized counter with empty hash' do
        expect(subject[:counter]).to eq({})
      end
    end

    describe '@traces' do
      subject { instance.traces }

      it { should be_empty }
    end

    describe '@delay' do
      subject { instance.instance_variable_get(:@delay) }
      it { should eq 60 }
    end

    describe '@per_request' do
      subject { instance.instance_variable_get(:@per_request) }
      it { should eq 100 }
    end

    describe '@sender' do
      subject { instance.instance_variable_get(:@sender) }

      it { should be_a Honeybadger::Monitor::Sender }
      it { should be_a Honeybadger::Sender }

      it 'is initialized with Honeybadger configuration' do
        Honeybadger::Monitor::Sender.should_receive(:new).with(Honeybadger.configuration)
        Honeybadger::Monitor::Worker.send(:new)
      end
    end

    it 'starts the worker loop'
  end

  describe '#start' do
    it 'creates a new Thread'
  end

  describe '#stop' do
    it 'asks current thread to exit gracefully'
  end

  describe '#timing' do
    before(:each) do
      expect(instance.metrics[:timing]).to be_empty
      instance.timing(:test, 50)
    end

    it 'adds value to metrics hash' do
      expect(instance.metrics[:timing][:test]).to eq [50]
    end

    it 'appends to existing values' do
      instance.timing(:test, 60)
      expect(instance.metrics[:timing][:test]).to eq [50, 60]
    end
  end

  describe '#increment' do
    before(:each) do
      expect(instance.metrics[:counter]).to be_empty
      instance.increment(:test, 50)
    end

    it 'adds value to metrics hash' do
      expect(instance.metrics[:counter][:test]).to eq [50]
    end

    it 'appends to existing values' do
      instance.increment(:test, 60)
      expect(instance.metrics[:counter][:test]).to eq [50, 60]
    end
  end

  describe '#send_metrics' do
    subject { instance.send(:send_metrics) }

    it 're-inits metrics' do
      instance.increment(:test, 60)
      previous_metrics = instance.metrics
      expect { subject }.to change(instance, :metrics).to({ :timing => {}, :counter => {} })
      expect(instance.metrics).not_to be(previous_metrics)
    end

    it 'returns nil when there are no metrics to send' do
      expect(instance.metrics[:timing]).to be_empty
      expect(instance.metrics[:counter]).to be_empty
      instance.sender.should_not_receive(:send_metrics)
      expect(subject).to be_nil
    end

    it 'returns nil after sending metrics' do
      instance.increment(:test, 60)
      instance.should_not_receive(:log)
      instance.sender.should_receive(:send_metrics)
      expect(subject).to be_nil
    end

    context 'when constructing timing metrics' do
      before(:each) { 10.times { |i| instance.timing(:test, i) } }

      it 'includes the mean value' do
        instance.sender.should_receive(:send_metrics).with(hash_including(:metrics => array_including(['test:mean 4.5'])))
      end

      it 'includes the median value' do
        instance.sender.should_receive(:send_metrics).with(hash_including(:metrics => array_including(['test:median 5'])))
      end

      it 'includes the percentile_90 value' do
        instance.sender.should_receive(:send_metrics).with(hash_including(:metrics => array_including(['test:percentile_90 9'])))
      end

      it 'includes the min value' do
        instance.sender.should_receive(:send_metrics).with(hash_including(:metrics => array_including(['test:min 0'])))
      end

      it 'includes the max value' do
        instance.sender.should_receive(:send_metrics).with(hash_including(:metrics => array_including(['test:max 9'])))
      end

      it 'includes the stddev value' do
        instance.sender.should_receive(:send_metrics).with(hash_including(:metrics => array_including(/test:stddev 3.027/)))
      end

      it 'includes a count of total metrics' do
        instance.sender.should_receive(:send_metrics).with(hash_including(:metrics => array_including(['test 10'])))
      end

      after(:each) { subject }
    end

    context 'when constructing counter metrics' do
      it 'sums the values of each metric' do
        10.times { instance.increment(:test, 1) }
        instance.sender.should_receive(:send_metrics).with(hash_including(:metrics => array_including('test 10')))
        subject
      end
    end

    context 'when sending metrics' do
      before(:each) { instance.increment(:test, 1) }

      it 'executes batches of 100' do
        199.times { |i| instance.increment(:"test_#{i}", 1) }
        instance.sender.should_receive(:send_metrics).exactly(2).times
      end

      it 'includes the configured environment' do
        Honeybadger.configure do |c|
          c.environment_name = 'asdf'
        end
        instance.sender.should_receive(:send_metrics).with(hash_including(:environment => 'asdf'))
      end

      it 'includes the configured hostname' do
        Honeybadger.configure do |c|
          c.hostname = 'zxcv'
        end
        instance.sender.should_receive(:send_metrics).with(hash_including(:hostname => 'zxcv'))
      end

      after(:each) { subject }
    end

    context 'when an exception occurrs' do
      before(:each) do
        instance.increment(:test, 1)
        instance.sender.stub(:send_metrics).and_raise(RuntimeError.new('cobra attack!'))
      end

      it 'logs the exception' do
        instance.should_receive(:log).with(:error, /cobra attack/)
        expect { subject }.not_to raise_error
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
