require 'honeybadger/config'
require 'net/http'

describe Honeybadger::Config do
  it { should_not be_valid }

  specify { expect(subject[:disabled]).to eq false }
  specify { expect(subject[:env]).to eq nil }
  specify { expect(subject[:'delayed_job.attempt_threshold']).to eq 0 }

  describe "#initialize" do
    let(:logger) { double('Logger', debug: nil, info: nil, warn: nil, error: nil) }

    context "with multiple forms of config" do
      it "overrides config with options" do
        config = Honeybadger::Config.new(logger: NULL_LOGGER, enabled: false)
        expect(config[:enabled]).to eq false
      end

      it "prefers ENV to options" do
        ENV['HONEYBADGER_ENABLED'] = 'true'
        config = Honeybadger::Config.new(logger: NULL_LOGGER, enabled: false)
        expect(config[:enabled]).to eq true
      end

      it "prefers file to options" do
        config = Honeybadger::Config.new(logger: NULL_LOGGER, :'config.path' => FIXTURES_PATH.join('honeybadger.yml'), api_key: 'bar')
        expect(config[:api_key]).to eq 'zxcv'
      end

      it "prefers ENV to file" do
        ENV['HONEYBADGER_API_KEY'] = 'foo'
        config = Honeybadger::Config.new(logger: NULL_LOGGER, :'config.path' => FIXTURES_PATH.join('honeybadger.yml'), api_key: 'bar')
        expect(config[:api_key]).to eq 'foo'
      end
    end

    context "when options include logger" do
      it "overrides configured logger" do
        config = Honeybadger::Config.new(logger: NULL_LOGGER)
        expect(config.logger).to eq NULL_LOGGER
      end
    end

    context "when a logging path is defined" do
      let(:log_file) { TMP_DIR.join('honeybadger.log') }

      before { log_file.delete if log_file.exist? }

      it "creates a log file" do
        expect(log_file.exist?).to eq false
        Honeybadger::Config.new(:'logging.path' => log_file)
        expect(log_file.exist?).to eq true
      end
    end
  end

  describe "#ping" do
    let(:instance) { Honeybadger::Config.new(logger: NULL_LOGGER, enabled: false, debug: true) }
    let(:logger) { instance.logger }
    let(:body) { {'top' => 'foo'} }

    subject { instance.ping }

    before do
      allow(logger).to receive(:debug)
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

      context "when body contains features" do
        let(:features) { {'foo' => 'bar'} }
        let(:body) { {features: features} }

        it "assigns the features" do
          expect { instance.ping }.to change { instance.features }.to({:foo => 'bar'})
        end
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

  describe "#framework" do
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
      its(:framework) { should eq :ruby }
    end

    context "framework is configured" do
      before { subject[:framework] = 'rack' }

      its(:framework) { should eq :rack }
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

      its(:framework) { should eq :rails }
      its(:framework_name) { should match /Rails 4\.1\.5/ }
    end

    context "Sinatra is installed" do
      before do
        sinatra = Module.new
        sinatra.const_set(:VERSION, '1.4.5')
        Object.const_set(:Sinatra, sinatra)
      end

      after { Object.send(:remove_const, :Sinatra) }

      its(:framework) { should eq :sinatra }
      its(:framework_name) { should match /Sinatra 1\.4\.5/ }
    end

    context "Rack is installed" do
      before do
        Object.const_set(:Rack, Module.new { def self.release; '1.0'; end; })
      end

      after { Object.send(:remove_const, :Rack) }

      its(:framework) { should eq :rack }
      its(:framework_name) { should match /Rack 1\.0/ }
    end
  end

  describe "#default_backend" do
    its(:default_backend) { should eq :server }

    context "when disabled explicitly" do
      before { subject[:report_data] = false }
      its(:default_backend) { should eq :null }
    end

    context "when environment is not a development environment" do
      before { subject[:env] = 'production' }
      its(:default_backend) { should eq :server }

      context "when disabled explicitly" do
        before { subject[:report_data] = false }
        its(:default_backend) { should eq :null }
      end
    end

    context "when environment is a development environment" do
      before { subject[:env] = 'development' }
      its(:default_backend) { should eq :null }

      context "when enabled explicitly" do
        before { subject[:report_data] = true }
        its(:default_backend) { should eq :server }
      end
    end
  end
end
