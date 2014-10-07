require 'honeybadger/agent'
require 'timecop'

describe Honeybadger::Agent do
  describe "instance methods" do
    let!(:instance) { described_class.new(config) }
    let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

    subject { instance }

    before do
      allow(config.logger).to receive(:debug)
    end

    after { instance.stop(true) }

    describe "#initialize" do
      describe "#metrics" do
        subject { instance.metrics }

        it { should be_a Honeybadger::Agent::MetricsCollector }
      end

      describe "#traces" do
        subject { instance.traces }

        it { should be_a Honeybadger::Agent::Batch }
      end

      describe "#workers" do
        subject { instance.workers }

        it { should be_a Hash }

        it "initializes a worker for each feature" do
          expect(subject[:notices]).to be_a Honeybadger::Agent::Worker
          expect(subject[:metrics]).to be_a Honeybadger::Agent::Worker
          expect(subject[:traces]).to be_a Honeybadger::Agent::Worker
        end
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

    describe "#start" do
      subject { instance.start }

      it { should eq true }

      it "logs debug info" do
        allow(config.logger).to receive(:debug)
        expect(config.logger).to receive(:debug).with(/start/i)
        instance.start
      end

      it "starts the thread" do
        expect { instance.start }.to change(instance, :thread).to(kind_of(Thread))
      end

      it "changes the pid to the current pid" do
        allow(Process).to receive(:pid).and_return(101)
        expect { instance.start }.to change(instance, :pid).to(101)
      end
    end

    describe "#work" do
      let(:trace) { double('Honeybadger::Trace') }

      before do
        allow(instance).to receive(:sleep)
        instance.metrics.timing('foo', 5)
        instance.traces.push(trace)
      end

      context "when under reporting interval" do
        it "doesn't flush anything" do
          expect(instance.workers[:metrics]).not_to receive(:push)
          expect(instance.workers[:traces]).not_to receive(:push)
        end
      end

      context "when over reporting interval" do
        it "flushes metrics and traces to workers" do
          expect(instance.workers[:metrics]).to receive(:push).with(kind_of(Honeybadger::Agent::MetricsCollector::Chunk))
          expect(instance.workers[:traces]).to receive(:push).with(kind_of(Honeybadger::Agent::Batch))

          Timecop.travel(Time.now + 1000) do
            instance.send(:work)
          end
        end
      end

      context "when an exception occurs" do
        before do
          allow(instance.metrics).to receive(:flush?).and_raise(RuntimeError.new('snakes!'))
        end

        it "does not re-raise error to caller" do
          expect { instance.send(:work) }.not_to raise_error
        end

        it "logs error info" do
          expect(config.logger).to receive(:error).with(/snakes/i)
          instance.send(:work)
        end

        it "sleeps for configured delay" do
          expect(instance).to receive(:sleep).with(kind_of(Integer))
          instance.send(:work)
        end
      end
    end
  end

  describe 'class methods' do
    NULL_BLOCK = Proc.new{}.freeze

    subject { described_class }

    its(:callbacks) { should be_a Honeybadger::Config::Callbacks }
    its(:instance) { should be_nil }

    describe "::exception_filter" do
      it "configures the exception_filter callback" do
        expect { described_class.exception_filter(&NULL_BLOCK) }.to change(described_class.callbacks, :exception_filter).from(nil).to(NULL_BLOCK)
      end
    end

    describe "::exception_fingerprint" do
      it "configures the exception_fingerprint callback" do
        expect { described_class.exception_fingerprint(&NULL_BLOCK) }.to change(described_class.callbacks, :exception_fingerprint).from(nil).to(NULL_BLOCK)
      end
    end

    describe "::backtrace_filter" do
      it "configures the backtrace_filter callback" do
        expect { described_class.backtrace_filter(&NULL_BLOCK) }.to change(described_class.callbacks, :backtrace_filter).from(nil).to(NULL_BLOCK)
      end
    end

    describe "::start" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER) }
      let(:logger) { config.logger }

      subject { described_class.start(config) }

      before do
        allow(config).to receive(:ping).and_return(true)

        # Don't actually load plugins
        allow(Honeybadger::Plugin).to receive(:instances).and_return({})
      end

      after { described_class.stop }

      context "when config is a hash" do
        let(:hash) { {api_key: 'asdf', logger: NULL_LOGGER} }

        it "generates a new config" do
          allow(config).to receive(:valid?).and_return(true)
          allow(Honeybadger::Config).to receive(:new).with(hash).and_return(config)
          expect(described_class).to receive(:new).with(config).and_call_original
          described_class.start(hash)
        end
      end

      context "when disabled" do
        before { config[:disabled] = true }

        it { should eq false }

        it "logs failure to start" do
          expect(logger).to receive(:warn).with(/disabled/)
          described_class.start(config)
        end

        it "doesn't create an instance" do
          expect { described_class.start(config) }.not_to change(Honeybadger::Agent, :instance)
        end
      end

      context "when config is invalid" do
        before { allow(config).to receive(:valid?) { false } }

        it { should eq false }

        it "logs failure to start" do
          expect(logger).to receive(:warn).with(/invalid/)
          described_class.start(config)
        end

        it "doesn't create an instance" do
          expect { described_class.start(config) }.not_to change(Honeybadger::Agent, :instance)
        end
      end

      context "when config is valid" do
        before { allow(config).to receive(:valid?) { true } }

        context "when ping fails" do
          before do
            allow(config).to receive(:ping).and_return(false)
          end

          it { should eq false }

          it "logs failure to start" do
            expect(logger).to receive(:warn).with(/failed to connect/)
            described_class.start(config)
          end

          it "doesn't create an instance" do
            expect { described_class.start(config) }.not_to change(Honeybadger::Agent, :instance)
          end
        end

        context "when ping succeeds" do
          it { should eq true }

          it "logs when started" do
            expect(logger).to receive(:info).with(/Starting Honeybadger/)
            described_class.start(config)
          end

          it "logs the version" do
            expect(logger).to receive(:info).with(/#{Regexp.escape(Honeybadger::VERSION)}/)
            described_class.start(config)
          end

          it "creates an instance" do
            instance = double('Honeybadger::Agent', start: true, stop: true)
            expect(described_class).to receive(:new).with(config).and_return(instance)
            expect { described_class.start(config) }.to change(Honeybadger::Agent, :instance).to(instance)
          end

          context "and a null backend is used" do
            it "warns when it's initialized" do
              config[:backend] = 'null'
              expect(logger).to receive(:warn).with(/development backend/)
              described_class.start(config)
            end
          end
        end
      end
    end
  end
end
