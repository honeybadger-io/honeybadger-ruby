require 'honeybadger/config'
require 'honeybadger/backend/base'
require 'net/http'

describe Honeybadger::Config do
  it { should_not be_valid }

  specify { expect(subject[:disabled]).to eq false }
  specify { expect(subject[:env]).to eq nil }
  specify { expect(subject[:'delayed_job.attempt_threshold']).to eq 0 }
  specify { expect(subject[:debug]).to eq false }

  describe "#init!" do
    let(:env) { {} }
    let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER) }

    before do
      allow(config).to receive(:ping).and_return(true)
    end

    it "returns the config object" do
      expect(config.init!).to eq(config)
    end

    context "with multiple forms of config" do
      it "overrides config with options" do
        config.init!(disabled: true)
        expect(config[:disabled]).to eq true
      end

      it "prefers ENV to options" do
        env['HONEYBADGER_DISABLED'] = 'true'
        config.init!({disabled: false}, env)
        expect(config[:disabled]).to eq true
      end

      it "prefers file to options" do
        config.init!(:'config.path' => FIXTURES_PATH.join('honeybadger.yml'), api_key: 'bar')
        expect(config[:api_key]).to eq 'zxcv'
      end

      it "prefers ENV to file" do
        env['HONEYBADGER_API_KEY'] = 'foo'
        config.init!({:'config.path' => FIXTURES_PATH.join('honeybadger.yml'), api_key: 'bar'}, env)
        expect(config[:api_key]).to eq 'foo'
      end
    end

    context "when a logging path is defined" do
      let(:log_file) { TMP_DIR.join('honeybadger.log') }

      before { log_file.delete if log_file.exist? }

      it "creates a log file" do
        expect(log_file.exist?).to eq false
        Honeybadger::Config.new.init!(:'logging.path' => log_file)
        expect(log_file.exist?).to eq true
      end
    end

    context "when options include logger" do
      it "overrides configured logger" do
        allow(NULL_LOGGER).to receive(:add)
        expect(NULL_LOGGER).to receive(:add).with(Logger::Severity::ERROR, /foo/)
        config = Honeybadger::Config.new.init!(logger: NULL_LOGGER)
        config.logger.error('foo')
      end
    end

    context "when the config path is defined" do
      let(:config_file) { TMP_DIR.join('honeybadger.yml') }
      let(:instance) { Honeybadger::Config.new(:'config.path' => config_file) }

      before { File.write(config_file, '') }
      after { File.unlink(config_file) }

      def init_instance
        instance.init!
      end

      context "when a config error occurrs while loading file" do
        before do
          allow(instance.logger).to receive(:add)
          allow(Honeybadger::Config::Yaml).to receive(:new).and_raise(Honeybadger::Config::ConfigError.new('ouch'))
        end

        it "does not raise an exception" do
          expect { init_instance }.not_to raise_error
        end

        it "logs the error message to the default logger" do
          expect(instance.logger).to receive(:add).with(Logger::Severity::ERROR, /ouch/)
          init_instance
        end
      end

      context "when a generic error occurrs while loading file" do
        before do
          allow(instance.logger).to receive(:add)
          allow(Honeybadger::Config::Yaml).to receive(:new).and_raise(RuntimeError.new('ouch'))
        end

        it "does not raise an exception" do
          expect { init_instance }.not_to raise_error
        end

        it "logs the error message to the default logger" do
          expect(instance.logger).to receive(:add).with(Logger::Severity::ERROR, /ouch/)
          init_instance
        end

        it "logs the backtrace to the boot logger" do
          expect(instance.logger).to receive(:add).with(Logger::Severity::ERROR, /config_spec\.rb/)
          init_instance
        end
      end
    end
  end

  describe "#get" do
    let(:instance) { Honeybadger::Config.new({logger: NULL_LOGGER, disabled: true, debug: true}.merge!(opts)) }
    let(:opts) { {} }

    context "when a normal option doesn't exist" do
      it 'returns the default option value' do
        expect(instance.get(:development_environments)).to eq Honeybadger::Config::DEFAULTS[:development_environments]
      end
    end

    context "when a normal option exists" do
      let(:opts) { { :development_environments => ['foo']} }

      it 'returns the option value' do
        expect(instance.get(:development_environments)).to eq ['foo']
      end
    end
  end

  describe "#ignored_classes" do
    let(:instance) { Honeybadger::Config.new({logger: NULL_LOGGER, disabled: true, debug: true}.merge!(opts)) }
    let(:opts) { { :'exceptions.ignore' => ['foo']} }

    it "returns the exceptions.ignore option value plus defaults" do
      expect(instance.ignored_classes).to eq(Honeybadger::Config::DEFAULTS[:'exceptions.ignore'] | ['foo'])
    end

    context "when exceptions.ignore_only is configured" do
      let(:opts) { { :'exceptions.ignore' => ['foo'], :'exceptions.ignore_only' => ['bar']} }

      it "returns the override" do
        expect(instance.ignored_classes).to eq(['bar'])
      end
    end
  end

  describe "#ping" do
    let(:instance) { Honeybadger::Config.new(logger: NULL_LOGGER, disabled: true, debug: true) }
    let(:logger) { instance.logger }
    let(:body) { {'top' => 'foo'} }

    subject { instance.ping }

    before do
      allow(logger).to receive(:debug)
    end

    it "calls the backend with object (not JSON)" do
      backend = double('Honeybadger::Backend::Server')
      response = Honeybadger::Backend::Response.new(201, '{}')
      allow(instance).to receive(:backend).and_return(backend)
      expect(backend).to receive(:notify).with(:ping, kind_of(Hash)).and_return(response)
      instance.ping
    end

    context "when connection succeeds" do
      before { stub_http(body: body.to_json) }

      it { should eq true }

      it "logs debug action" do
        expect(logger).to receive(:debug).with(/ping payload/i)
        instance.ping
      end

      it "logs debug response" do
        expect(logger).to receive(:debug).with(/ping response/i)
        instance.ping
      end
    end

    context "when connection fails" do
      before do
        stub_http(response: Net::HTTPServerError.new('1.2', '500', 'Internal Error'), body: nil)
      end

      it { should eq false }

      it "warns logger" do
        expect(logger).to receive(:warn).with(/ping failure code=500 message="Internal Error"/)
        instance.ping
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
      before { subject[:framework] = 'rack' }

      its(:detected_framework) { should eq :rack }
    end

    context "Rails is installed" do
      before do
        rails = Module.new
        version = Module.new
        version.const_set(:STRING, '4.1.5')
        rails.const_set(:VERSION, version)
        Object.const_set(:Rails, rails)
      end

      after { Object.send(:remove_const, :Rails) }

      its(:detected_framework) { should eq :rails }
      its(:framework_name) { should match /Rails 4\.1\.5/ }
    end

    context "Sinatra is installed" do
      before do
        sinatra = Module.new
        sinatra.const_set(:VERSION, '1.4.5')
        Object.const_set(:Sinatra, sinatra)
      end

      after { Object.send(:remove_const, :Sinatra) }

      its(:detected_framework) { should eq :sinatra }
      its(:framework_name) { should match /Sinatra 1\.4\.5/ }
    end

    context "Rack is installed" do
      before do
        Object.const_set(:Rack, Module.new { def self.release; '1.0'; end; })
      end

      after { Object.send(:remove_const, :Rack) }

      its(:detected_framework) { should eq :rack }
      its(:framework_name) { should match /Rack 1\.0/ }
    end
  end

  describe "#default_backend" do
    its(:default_backend) { should be_a Honeybadger::Backend::Server }

    context "when disabled explicitly" do
      before { subject[:report_data] = false }
      its(:default_backend) { should be_a Honeybadger::Backend::Null }
    end

    context "when environment is not a development environment" do
      before { subject[:env] = 'production' }
      its(:default_backend) { should be_a Honeybadger::Backend::Server }

      context "when disabled explicitly" do
        before { subject[:report_data] = false }
        its(:default_backend) { should be_a Honeybadger::Backend::Null }
      end
    end

    context "when environment is a development environment" do
      before { subject[:env] = 'development' }
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
      let(:root) { '/bar' }
      it { should match '/bar/baz' }
      it { should_not match '/foo/bar/baz' }
    end

    context "when root is blank" do
      let(:root) { '' }
      it { should be_nil }
    end
  end
end
