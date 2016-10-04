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
      describe "#workers" do
        subject { instance.workers }

        it { should be_a Hash }

        it "initializes a worker for each feature" do
          expect(subject[:notices]).to be_a Honeybadger::Agent::Worker
        end
      end
    end

    describe "#push" do
      subject { instance.send(:push, :foo, obj) }
      let(:obj) { double() }

      context "when disabled by ping" do
        before { config.features[:foo] = false }

        it { should eq false }

        it "logs debug output" do
          expect(config.logger).to receive(:debug).with(/dropping feature=foo/i)
          subject
        end

        it "does not push to worker" do
          expect(instance.workers[:foo]).not_to receive(:push)
          subject
        end
      end
    end

    describe "#flush" do
      subject { instance.flush(&block) }

      context "when no block is given" do
        let(:block) { nil }
        it { should eq true }

        it "flushes workers" do
          expect(instance.workers[:notices]).to receive(:flush)
          subject
        end
      end

      context "when no block is given" do
        let(:block) { Proc.new { expecting.call } }
        let(:expecting) { double(call: true) }

        it { should eq true }

        it "executes the block" do
          expect(expecting).to receive(:call)
          subject
        end

        it "flushes workers" do
          expect(instance.workers[:notices]).to receive(:flush)
          subject
        end
      end

      context "when an exception occurs" do
        let(:block) { Proc.new { fail 'oops' } }

        it "flushes workers" do
          expect(instance.workers[:notices]).to receive(:flush)
          expect { subject }.to raise_error /oops/
        end
      end
    end
  end

  describe 'class methods' do
    NULL_BLOCK = Proc.new{}.freeze

    subject { described_class }

    its(:callbacks) { should be_a Honeybadger::Config::Callbacks }
    its(:instance) { should be_nil }

    describe "::flush" do
      let(:block) { nil }

      subject { described_class.flush(&block) }

      context "when idle" do
        it { should eq false }

        context "and a block is given" do
          let(:block) { Proc.new { expecting.call } }
          let(:expecting) { double(call: true) }

          it "executes the block" do
            expect(expecting).to receive(:call)
            subject
          end
        end
      end

      context "when running" do
        let(:instance) { double('Honeybadger::Agent', flush: :flush) }

        before do
          allow(described_class).to receive(:instance).and_return(instance)
        end

        it "delegates to instance" do
          expect(instance).to receive(:flush)
          expect(described_class.flush).to eq :flush
        end
      end
    end

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

          it { should eq true }

          it "logs failure to start" do
            expect(logger).to receive(:warn).with(/failed to connect/i)
            described_class.start(config)
          end

          it "creates an instance" do
            instance = double('Honeybadger::Agent', start: true, stop: true)
            expect(described_class).to receive(:new).with(config).and_return(instance)
            expect { described_class.start(config) }.to change(Honeybadger::Agent, :instance).to(instance)
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
