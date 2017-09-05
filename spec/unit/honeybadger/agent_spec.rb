require 'honeybadger/agent'
require 'timecop'

describe Honeybadger::Agent do
  NULL_BLOCK = Proc.new{}.freeze

  describe "class methods" do
    subject { described_class }

    its(:instance) { should be_a(Honeybadger::Agent) }
  end

  describe "#notify" do
    it "generates a backtrace" do
      config = Honeybadger::Config.new(api_key:'fake api key', logger: NULL_LOGGER)
      instance = described_class.new(config)

      expect(instance.worker).to receive(:push) do |notice|
        expect(notice.backtrace.to_a[0][:file]).to eq('[PROJECT_ROOT]/spec/unit/honeybadger/agent_spec.rb')
      end

      instance.notify(error_message: 'testing backtrace generation')
    end
  end

  context do
    let!(:instance) { described_class.new(config) }
    let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

    subject { instance }

    before do
      allow(config.logger).to receive(:debug)
    end

    after { instance.stop(true) }

    describe "#initialize" do
      describe "#worker" do
        subject { instance.worker }

        it { should be_a Honeybadger::Worker }
      end
    end

    describe "#flush" do
      subject { instance.flush(&block) }

      context "when no block is given" do
        let(:block) { nil }
        it { should eq true }

        it "flushes worker" do
          expect(instance.worker).to receive(:flush)
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

        it "flushes worker" do
          expect(instance.worker).to receive(:flush)
          subject
        end
      end

      context "when an exception occurs" do
        let(:block) { Proc.new { fail 'oops' } }

        it "flushes worker" do
          expect(instance.worker).to receive(:flush)
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

    describe "#local_variable_filter" do
      it "configures the local_variable_filter callback" do
        expect { instance.local_variable_filter(&NULL_BLOCK) }.to change(instance.config, :local_variable_filter).from(nil).to(NULL_BLOCK)
      end
    end
  end
end
