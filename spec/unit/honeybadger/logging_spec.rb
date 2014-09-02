require 'honeybadger/logging'

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
