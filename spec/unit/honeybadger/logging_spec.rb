LOG_SEVERITIES = [:debug, :info, :warn, :error, :fatal].freeze

describe Honeybadger::Logging::Base do
  LOG_SEVERITIES.each do |severity|
    it { should respond_to severity }
  end

  describe "#add" do
    it "requires subclass to define it" do
      expect { subject.add(1, 'snakes!').to raise_error NotImplementedError }
    end
  end
end

describe Honeybadger::Logging::BootLogger.instance do
  LOG_SEVERITIES.each do |severity|
    it { should respond_to severity }

    it "flushes ##{severity} messages to logger" do
      subject.send(severity, :foo)
      logger = double('Logger')
      expect(logger).to receive(:add).with(Logger::Severity.const_get(severity.to_s.upcase), :foo)
      subject.flush(logger)
    end
  end
end

describe Honeybadger::Logging::FormattedLogger do
  let(:logger) { Logger.new('/dev/null') }

  subject { described_class.new(logger) }

  LOG_SEVERITIES.each do |severity|
    it { should respond_to severity }

    it "delegates ##{severity} to configured logger" do
      expect(logger).to receive(:add).with(Logger::Severity.const_get(severity.to_s.upcase), :foo)
      subject.send(severity, :foo)
    end
  end
end

describe Honeybadger::Logging::ConfigLogger do
  let(:config) { Honeybadger::Config.new(logger: logger, debug: true, :'logging.tty_level' => tty_level) }
  let(:logger) { Logger.new('/dev/null') }
  let(:tty_level) { 'ERROR' }

  subject { described_class.new(config, logger) }

  LOG_SEVERITIES.each do |severity|
    it { should respond_to severity }
  end

  context "when not attached to terminal", unless: STDOUT.tty? do
    LOG_SEVERITIES.each do |severity|
      it "delegates ##{severity} to configured logger" do
        # Debug is logged at the info level.
        const = Logger::Severity.const_get((severity == :debug ? :info : severity).to_s.upcase)
        expect(logger).to receive(:add).with(const, :foo)
        subject.send(severity, :foo)
      end
    end
  end

  context "when attached to terminal", if: STDOUT.tty? do
    [:debug, :info, :warn].each do |severity|
      it "suppresses ##{severity} from configured logger" do
        expect(logger).not_to receive(:add)
        subject.send(severity, :foo)
      end
    end

    [:error, :fatal].each do |severity|
      it "delegates ##{severity} to configured logger" do
        expect(logger).to receive(:add).with(Logger::Severity.const_get(severity.to_s.upcase), :foo)
        subject.send(severity, :foo)
      end
    end

    context "and logging.tty is enabled" do
      let(:tty_level) { 'DEBUG' }

      LOG_SEVERITIES.each do |severity|
        it "delegates ##{severity} to configured logger" do
          # Debug is logged at the info level.
          const = Logger::Severity.const_get((severity == :debug ? :info : severity).to_s.upcase)
          expect(logger).to receive(:add).with(const, :foo)
          subject.send(severity, :foo)
        end
      end
    end
  end
end
