require 'honeybadger/agent'
require 'timecop'

describe Honeybadger::Agent do
  NULL_BLOCK = Proc.new{}.freeze

  describe "class methods" do
    subject { described_class }

    its(:instance) { should be_a(Honeybadger::Agent) }
  end

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

    describe "#exception_filter" do
      it "configures the exception_filter callback" do
        expect { instance.exception_filter(&NULL_BLOCK) }.to change(instance.config, :exception_filter).from(nil).to(NULL_BLOCK)
      end
    end

    describe "#exception_fingerprint" do
      it "configures the exception_fingerprint callback" do
        expect { instance.exception_fingerprint(&NULL_BLOCK) }.to change(instance.config, :exception_fingerprint).from(nil).to(NULL_BLOCK)
      end
    end

    describe "#backtrace_filter" do
      it "configures the backtrace_filter callback" do
        expect { instance.backtrace_filter(&NULL_BLOCK) }.to change(instance.config, :backtrace_filter).from(nil).to(NULL_BLOCK)
      end
    end
  end
end
