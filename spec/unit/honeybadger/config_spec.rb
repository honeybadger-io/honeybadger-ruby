require "honeybadger/config"
require "honeybadger/backend/base"
require "net/http"

INIT_LOGGER = Logger.new(File::NULL)
CONFIGURE_LOGGER = Logger.new(File::NULL)

RSpec.describe Honeybadger::Config do
  specify { expect(subject[:env]).to eq nil }
  specify { expect(subject[:"delayed_job.attempt_threshold"]).to eq 0 }
  specify { expect(subject[:debug]).to eq false }

  describe "#init!" do
    let(:env) { {} }
    let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER) }

    it "returns the config object" do
      expect(config.init!).to eq(config)
    end

    context "with multiple forms of config" do
      it "overrides config with options" do
        config.init!(report_data: true)
        expect(config[:report_data]).to eq true
      end

      it "prefers ENV to options" do
        env["HONEYBADGER_API_KEY"] = "dan"
        config.init!({api_key: "muj"}, env)
        expect(config[:api_key]).to eq "dan"
      end

      it "prefers file to options" do
        config.init!("config.path": FIXTURES_PATH.join("honeybadger.yml"), api_key: "bar")
        expect(config[:api_key]).to eq "zxcv"
      end

      it "prefers ENV to file" do
        env["HONEYBADGER_API_KEY"] = "foo"
        config.init!({"config.path": FIXTURES_PATH.join("honeybadger.yml"), api_key: "bar"}, env)
        expect(config[:api_key]).to eq "foo"
      end
    end

    context "when a logging path is defined" do
      let(:log_file) { TMP_DIR.join("honeybadger.log") }

      before { log_file.delete if log_file.exist? }

      it "creates a log file" do
        expect(log_file.exist?).to eq false
        Honeybadger::Config.new.init!("logging.path": log_file)
        expect(log_file.exist?).to eq true
      end
    end

    context "when options include logger" do
      it "overrides configured logger" do
        allow(NULL_LOGGER).to receive(:add)
        expect(NULL_LOGGER).to receive(:add).with(Logger::Severity::ERROR, /foo/, "honeybadger")
        config = Honeybadger::Config.new.init!(logger: NULL_LOGGER)
        config.logger.error("foo")
      end
    end

    context "when the config path is defined" do
      let(:config_file) { TMP_DIR.join("honeybadger.yml") }
      let(:instance) { Honeybadger::Config.new("config.path": config_file) }

      before { File.write(config_file, "") }
      after { File.unlink(config_file) }

      def init_instance
        instance.init!
      end

      context "when a config error occurs while loading file" do
        before do
          allow(instance.logger).to receive(:add)
          allow(Honeybadger::Config::Yaml).to receive(:new).and_raise(Honeybadger::Config::ConfigError.new("ouch"))
        end

        it "raises the exception" do
          expect { init_instance }.to raise_error(Honeybadger::Config::ConfigError)
        end
      end

      context "when a generic error occurs while loading file" do
        before do
          allow(instance.logger).to receive(:add)
          allow(Honeybadger::Config::Yaml).to receive(:new).and_raise(RuntimeError.new("ouch"))
        end

        it "raises the exception" do
          expect { init_instance }.to raise_error(RuntimeError)
        end
      end
    end

    context "when options are deprecated" do
      before do
        # Unfreeze the constant to allow proxying for method expectations
        stub_const("Honeybadger::Config::OPTIONS", Honeybadger::Config::OPTIONS.dup)
        allow(Honeybadger::Config::OPTIONS).to receive(:dig).with(anything, :deprecated).and_return(nil)
        allow(Honeybadger::Config::OPTIONS).to receive(:dig).with(anything, :deprecated_by).and_call_original
        allow(Honeybadger::Config::OPTIONS).to receive(:dig).with(:env, :deprecated).and_return(
          deprecated_value
        )
      end

      context "with a deprecation message" do
        let(:deprecated_value) { "The option `env` is deprecated. Use `environment_name` instead." }

        it "logs a deprecation warning with the message" do
          expect(NULL_LOGGER).to receive(:add).with(Logger::Severity::WARN, a_string_including(
            "`env`",
            "`environment_name`",
            "config_source=framework"
          ), "honeybadger")
          config.init!(api_key: "expected_api_key", env: "expected_env")
          expect(config[:api_key]).to eq "expected_api_key"
          expect(config[:env]).to eq "expected_env"
        end
      end

      context "without a deprecation message" do
        let(:deprecated_value) { true }

        it "logs a deprecation warning with the default message" do
          expect(NULL_LOGGER).to receive(:add).with(Logger::Severity::WARN, a_string_including(
            "`env`",
            "no effect",
            "config_source=framework"
          ), "honeybadger")
          config.init!(api_key: "expected_api_key", env: "expected_env")
          expect(config[:api_key]).to eq "expected_api_key"
          expect(config[:env]).to eq "expected_env"
        end
      end

      context "with deprecated_by option" do
        let(:deprecated_value) { true }

        before do
          allow(Honeybadger::Config::OPTIONS).to receive(:dig).with(:env, :deprecated_by).and_return(:deprecated_by_env)
        end

        context "when the deprecated_by key is not configured" do
          it "logs a deprecation warning and configures the deprecated_by key" do
            expect(NULL_LOGGER).to receive(:add).with(Logger::Severity::WARN, a_string_including(
              "`env`",
              "`deprecated_by_env`",
              "config_source=framework"
            ), "honeybadger")
            config.init!(api_key: "expected_api_key", env: "expected_env")
            expect(config[:api_key]).to eq "expected_api_key"
            expect(config[:env]).to be_nil
            expect(config[:deprecated_by_env]).to eq "expected_env"
          end
        end

        context "when the deprecated_by key is configured" do
          it "logs a deprecation warning without overriding the deprecated_by key" do
            expect(NULL_LOGGER).to receive(:add).with(Logger::Severity::WARN, a_string_including(
              "`env`",
              "`deprecated_by_env`",
              "config_source=framework"
            ), "honeybadger")
            config.init!(api_key: "expected_api_key", env: "noop_env", deprecated_by_env: "expected_env")
            expect(config[:api_key]).to eq "expected_api_key"
            expect(config[:env]).to be_nil
            expect(config[:deprecated_by_env]).to eq "expected_env"
          end
        end
      end
    end
  end

  describe "#get" do
    let(:instance) { Honeybadger::Config.new({logger: NULL_LOGGER, debug: true}.merge!(opts)) }
    let(:opts) { {} }

    context "when a normal option doesn't exist" do
      it "returns the default option value" do
        expect(instance.get(:development_environments)).to eq Honeybadger::Config::DEFAULTS[:development_environments]
      end
    end

    context "when a normal option exists" do
      let(:opts) { {development_environments: ["foo"]} }

      it "returns the option value" do
        expect(instance.get(:development_environments)).to eq ["foo"]
      end
    end
  end

  describe "#ignored_classes" do
    let(:instance) { Honeybadger::Config.new({logger: NULL_LOGGER, debug: true}.merge!(opts)) }
    let(:opts) { {"exceptions.ignore": ["foo"]} }

    it "returns the exceptions.ignore option value plus defaults" do
      expect(instance.ignored_classes).to eq(Honeybadger::Config::DEFAULTS[:"exceptions.ignore"] | ["foo"])
    end

    context "when exceptions.ignore_only is configured" do
      let(:opts) { {"exceptions.ignore": ["foo"], "exceptions.ignore_only": ["bar"]} }

      it "returns the override" do
        expect(instance.ignored_classes).to eq(["bar"])
      end
    end
  end

  describe "#detected_framework" do
    constants = [:Rails, :Sinatra, :Rack]
    constants_backup = {}

    before(:all) do
      constants.each do |const|
        if Object.const_defined?(const)
          constants_backup[const] = Object.const_get(const)
          Object.send(:remove_const, const)
        end
      end
    end

    after(:all) do
      constants.each do |const|
        Object.const_set(const, constants_backup[const]) if constants_backup[const]
      end
    end

    context "by default" do
      its(:detected_framework) { should eq :ruby }
    end

    context "framework is configured" do
      before { subject[:framework] = "rack" }

      its(:detected_framework) { should eq :rack }
    end

    context "Rails is installed" do
      before do
        rails = Module.new
        version = Module.new
        version.const_set(:STRING, "4.1.5")
        rails.const_set(:VERSION, version)
        Object.const_set(:Rails, rails)
      end

      after { Object.send(:remove_const, :Rails) }

      its(:detected_framework) { should eq :rails }
      its(:framework_name) { should match(/Rails 4\.1\.5/) }
    end

    context "Sinatra is installed" do
      before do
        sinatra = Module.new
        sinatra.const_set(:VERSION, "1.4.5")
        Object.const_set(:Sinatra, sinatra)
      end

      after { Object.send(:remove_const, :Sinatra) }

      its(:detected_framework) { should eq :sinatra }
      its(:framework_name) { should match(/Sinatra 1\.4\.5/) }
    end

    context "Rack is installed" do
      before do
        Object.const_set(:Rack, Module.new {
                                  def self.release
                                    "1.0"
                                  end; })
      end

      after { Object.send(:remove_const, :Rack) }

      its(:detected_framework) { should eq :rack }
      its(:framework_name) { should match(/Rack 1\.0/) }
    end
  end

  describe "#default_backend" do
    its(:default_backend) { should be_a Honeybadger::Backend::Server }

    context "when disabled explicitly" do
      before { subject[:report_data] = false }
      its(:default_backend) { should be_a Honeybadger::Backend::Null }
    end

    context "when environment is not a development environment" do
      before { subject[:env] = "production" }
      its(:default_backend) { should be_a Honeybadger::Backend::Server }

      context "when disabled explicitly" do
        before { subject[:report_data] = false }
        its(:default_backend) { should be_a Honeybadger::Backend::Null }
      end
    end

    context "when environment is a development environment" do
      before { subject[:env] = "development" }
      its(:default_backend) { should be_a Honeybadger::Backend::Null }

      context "when enabled explicitly" do
        before { subject[:report_data] = true }
        its(:default_backend) { should be_a Honeybadger::Backend::Server }
      end
    end
  end

  describe "#root_regexp" do
    let(:instance) { described_class.new(root: root) }

    subject { instance.root_regexp }

    context "when root is missing" do
      let(:root) { nil }
      it { should be_nil }
    end

    context "when root is present" do
      let(:root) { "/bar" }
      it { should match "/bar/baz" }
      it { should_not match "/foo/bar/baz" }
    end

    context "when root is blank" do
      let(:root) { "" }
      it { should be_nil }
    end
  end

  describe "#configure" do
    context "when the app has already been initialized" do
      it "overrides the logger with the configured logger" do
        honeybadger = Honeybadger::Config.new.init!(logger: INIT_LOGGER)

        honeybadger.configure do |config|
          config.logger = CONFIGURE_LOGGER
        end

        expect(CONFIGURE_LOGGER).to receive(:add).with(Logger::Severity::ERROR, /foo/, "honeybadger")

        honeybadger.logger.error("foo")
      end
    end

    it "configures multiple before_notify hooks" do
      subject.configure do |config|
        config.before_notify { |n| n }
      end

      subject.configure do |config|
        config.before_notify { |n| n }
      end

      expect(subject.before_notify_hooks.size).to eq(2)
    end

    it "only responds to methods that correspond to default keys" do
      known_key_response = nil
      unknown_key_response = nil

      subject.configure do |config|
        known_key_response = config.respond_to?(:api_key)
      end

      subject.configure do |config|
        unknown_key_response = config.respond_to?(:ejfhjskdhfkdjhf=)
      end

      expect(known_key_response).to eq(true)
      expect(unknown_key_response).to eq(false)
    end
  end

  describe "#ignored_events" do
    let(:config) { Honeybadger::Config.new("events.ignore_only": ignored_events) }

    context "empty array" do
      let(:ignored_events) { [] }
      it { expect(config.ignored_events).to eq([]) }
    end

    context "a string" do
      let(:ignored_events) { ["foo"] }
      it { expect(config.ignored_events).to eq([{[:event_type] => "foo"}]) }
    end

    context "a regex" do
      let(:ignored_events) { [/foo/] }
      it { expect(config.ignored_events).to eq([{[:event_type] => /foo/}]) }
    end

    context "a simple hash" do
      let(:ignored_events) { [{foo: "bar"}] }
      it { expect(config.ignored_events).to eq([{[:foo] => "bar"}]) }
    end

    context "a simple hash with a regex value" do
      let(:ignored_events) { [{foo: /bar/}] }
      it { expect(config.ignored_events).to eq([{[:foo] => /bar/}]) }
    end
  end
end
