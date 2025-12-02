require "honeybadger/breadcrumbs/logging"

describe Honeybadger::Breadcrumbs::LogWrapper do
  let(:logger) do
    Class.new do
      prepend Honeybadger::Breadcrumbs::LogWrapper

      attr_reader :severity, :message, :progname

      def add(severity, message, progname)
        @severity = severity
        @message = message
        @progname = progname
      end

      def format_severity(str)
        str
      end
    end
  end

  subject { logger.new }

  it "adds a breadcrumb" do
    expect(subject).to receive(:format_severity).and_return("debug")
    expect(Honeybadger).to receive(:add_breadcrumb).with("Message", hash_including(category: :log, metadata: hash_including(severity: "debug", progname: "none")))

    subject.add("test", "Message", "none")
  end

  it "handles non-string objects" do
    expect(Honeybadger).to receive(:add_breadcrumb).with("{}", anything)
    subject.add("DEBUG", {})
  end

  it "handles invalid UTF-8 byte sequences" do
    invalid_string = "\xE9s"
    expect(Honeybadger).to receive(:add_breadcrumb).with("?s", anything)
    subject.add("DEBUG", invalid_string)
  end

  it "does not mutate the message" do
    subject.add("DEBUG", {}, "Honeybadger")
    expect(subject.severity).to eq("DEBUG")
    expect(subject.message).to eq({})
    expect(subject.progname).to eq("Honeybadger")
  end

  it "does not crash when message.to_s returns nil" do
    logger = Logger.new(nil)
    logger.extend(Honeybadger::Breadcrumbs::LogWrapper)

    bad = Class.new { def to_s; nil; end }.new

    expect { logger.add(Logger::ERROR, bad) }.not_to raise_error
  end


  describe "ignores messages on" do
    before { expect(Honeybadger).to_not receive(:add_breadcrumb) }

    it "nil message" do
      subject.add("test", nil)
    end

    it "empty string" do
      subject.add("test", "")
    end

    it "honeybadger progname" do
      subject.add("test", "noop", "honeybadger")
    end

    it "within log_subscriber call" do
      Thread.current[:__hb_within_log_subscriber] = true
      subject.add("test", "a message")
      Thread.current[:__hb_within_log_subscriber] = false
    end
  end
end
