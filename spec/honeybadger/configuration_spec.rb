require 'spec_helper'
require 'socket'

describe Honeybadger::Configuration do
  it "provides default values" do
    assert_config_default :api_key,             nil
    assert_config_default :proxy_host,          nil
    assert_config_default :proxy_port,          nil
    assert_config_default :proxy_user,          nil
    assert_config_default :proxy_pass,          nil
    assert_config_default :project_root,        nil
    assert_config_default :environment_name,    nil
    assert_config_default :logger,              nil
    assert_config_default :notifier_version,    Honeybadger::VERSION
    assert_config_default :notifier_name,       'Honeybadger Notifier'
    assert_config_default :notifier_url,        'https://github.com/honeybadger-io/honeybadger-ruby'
    assert_config_default :secure,              true
    assert_config_default :host,                'api.honeybadger.io'
    assert_config_default :http_open_timeout,   2
    assert_config_default :http_read_timeout,   5
    assert_config_default :ignore_by_filters,   []
    assert_config_default :ignore_user_agent,   []
    assert_config_default :params_filters,
                          Honeybadger::Configuration::DEFAULT_PARAMS_FILTERS
    assert_config_default :backtrace_filters,
                          Honeybadger::Configuration::DEFAULT_BACKTRACE_FILTERS
    assert_config_default :ignore,
                          Honeybadger::Configuration::IGNORE_DEFAULT
    assert_config_default :framework, 'Standalone'
    assert_config_default :source_extract_radius, 2
    assert_config_default :async, nil
    assert_config_default :send_request_session, true
    assert_config_default :send_local_variables, false
    assert_config_default :unwrap_exceptions, true
    assert_config_default :debug, false
    assert_config_default :log_exception_on_send_failure, false
    assert_config_default :fingerprint, nil
    assert_config_default :hostname, Socket.gethostname
    assert_config_default :feedback, true
    assert_config_default :features, {'notices' => true, 'local_variables' => true}
  end

  it "configures async as Proc" do
    config = Honeybadger::Configuration.new
    async_handler = Proc.new { |n| n.deliver }
    expect(config.async?).to be_false
    config.async = async_handler
    expect(config.async?).to be_true
    expect(config.async).to be async_handler
  end

  it "configures async with block" do
    config = Honeybadger::Configuration.new
    expect(config.async?).to be_false
    config.async { |n| n }
    expect(config.async?).to be_true
    expect(config.async.call('foo')).to eq 'foo'
  end

  it "configures fingerprint as Proc" do
    config = Honeybadger::Configuration.new
    fingerprint_generator = Proc.new { |n| n[:error_class] }
    config.fingerprint = fingerprint_generator
    expect(config.fingerprint.call({ :error_class => 'foo' })).to eq 'foo'
  end

  it "configures fingerprint with block" do
    config = Honeybadger::Configuration.new
    config.fingerprint { |n| n[:error_class] }
    expect(config.fingerprint.call({ :error_class => 'foo' })).to eq 'foo'
  end

  it "stubs current_user_method" do
    config = Honeybadger::Configuration.new
    expect { config.current_user_method = :foo }.not_to raise_error
  end

  it "provides default values for secure connections" do
    config = Honeybadger::Configuration.new
    config.secure = true
    expect(config.port).to eq 443
    expect(config.protocol).to eq 'https'
  end

  it "provides default values for insecure connections" do
    config = Honeybadger::Configuration.new
    config.secure = false
    expect(config.port).to eq 80
    expect(config.protocol).to eq 'http'
  end

  it "does not cache inferred ports" do
    config = Honeybadger::Configuration.new
    config.secure = false
    config.port
    config.secure = true
    expect(config.port).to eq 443
  end

  it "allows values to be overwritten" do
    assert_config_overridable :proxy_host
    assert_config_overridable :proxy_port
    assert_config_overridable :proxy_user
    assert_config_overridable :proxy_pass
    assert_config_overridable :secure
    assert_config_overridable :host
    assert_config_overridable :port
    assert_config_overridable :http_open_timeout
    assert_config_overridable :http_read_timeout
    assert_config_overridable :project_root
    assert_config_overridable :notifier_version
    assert_config_overridable :notifier_name
    assert_config_overridable :notifier_url
    assert_config_overridable :environment_name
    assert_config_overridable :logger
    assert_config_overridable :source_extract_radius
    assert_config_overridable :async
    assert_config_overridable :fingerprint
    assert_config_overridable :send_request_session
    assert_config_overridable :debug
    assert_config_overridable :hostname
    assert_config_overridable :features
    assert_config_overridable :metrics
    assert_config_overridable :feedback
    assert_config_overridable :log_exception_on_send_failure
  end

  it "has an api key" do
    assert_config_overridable :api_key
  end

  it "acts like a hash" do
    config = Honeybadger::Configuration.new
    hash = config.to_hash
    [:api_key, :backtrace_filters, :development_environments,
     :environment_name, :host, :http_open_timeout, :http_read_timeout, :ignore,
     :ignore_by_filters, :ignore_user_agent, :notifier_name, :notifier_url,
     :notifier_version, :params_filters, :project_root, :port, :protocol,
     :proxy_host, :proxy_pass, :proxy_port, :proxy_user, :secure,
     :source_extract_radius, :async, :send_request_session, :debug,
     :fingerprint, :hostname, :features, :metrics, :feedback,
     :log_exception_on_send_failure, :unwrap_exceptions].each do |option|
       expect(hash[option]).to eq config[option]
    end
  end

  it "is mergable" do
    config = Honeybadger::Configuration.new
    hash = config.to_hash
    expect(hash.merge(:key => 'value')).to eq config.merge(:key => 'value')
  end

  it "allows param filters to be appended" do
    assert_appends_value :params_filters
  end

  it "allows ignored user agents to be appended" do
    assert_appends_value :ignore_user_agent
  end

  it "allows backtrace filters to be appended" do
    assert_appends_value(:backtrace_filters) do |config|
      new_filter = lambda {}
      config.filter_backtrace(&new_filter)
      new_filter
    end
  end

  it "allows ignore by filters to be appended" do
    assert_appends_value(:ignore_by_filters) do |config|
      new_filter = lambda {}
      config.ignore_by_filter(&new_filter)
      new_filter
    end
  end

  it "allows ignored exceptions to be appended" do
    config = Honeybadger::Configuration.new
    original_filters = config.ignore.dup
    new_filter = 'hello'
    config.ignore << new_filter
    expect(original_filters + [new_filter]).to eq config.ignore
  end

  it "allows ignored exceptions to be replaced" do
    assert_replaces(:ignore, :ignore_only=)
  end

  it "allows ignored user agents to be replaced" do
    assert_replaces(:ignore_user_agent, :ignore_user_agent_only=)
  end

  it "uses development and test as development environments by default" do
    config = Honeybadger::Configuration.new
    expect(config.development_environments).to eq %w(development test cucumber)
  end

  describe "#public?" do
    let(:config) { Honeybadger::Configuration.new }

    subject { config.public? }

    before do
      config.api_key = 'asdf'
    end

    context "when api_key is not configured" do
      before { config.api_key = nil }

      it { should be_false }
    end

    context "when api_key is configured" do
      it { should be_true }
    end

    context "without an environment name" do
      it { should be_true }
    end

    context "when environment is public" do
      before do
        config.development_environments = %w(development)
        config.environment_name = 'production'
      end

      it { should be_true }
    end

    context "when environment is development" do
      before do
        config.development_environments = %w(development)
        config.environment_name = 'development'
      end

      it { should be_false }
    end
  end

  describe "#metrics?" do
    let(:config) { Honeybadger::Configuration.new }

    context "when public" do
      before { config.stub(:public?).and_return(true) }

      it "sends metrics by default" do
        expect(config.metrics?).to be_true
      end

      context "when disabled" do
        before { config.metrics = false }

        it "does not send metrics" do
          expect(config.metrics?).to be_false
        end
      end
    end

    context "when not public" do
      before { config.stub(:public?).and_return(false) }

      it "does not send metrics" do
        expect(config.metrics?).to be_false
      end
    end
  end

  it "uses the assigned logger if set" do
    config = Honeybadger::Configuration.new
    config.logger = "CUSTOM LOGGER"
    expect(config.logger).to eq "CUSTOM LOGGER"
  end

  it "gives a new instance if non defined" do
    Honeybadger.configuration = nil
    expect(Honeybadger.configuration).to be_a Honeybadger::Configuration
  end

  describe '#trace_threshold=' do
    let(:config) { Honeybadger::Configuration.new }

    subject { config.trace_threshold = value; config.trace_threshold }

    context "value is above 1000" do
      let(:value) { 2000 }

      it { should eq 2000 }
    end

    context "value is below 1000" do
      let(:value) { 100 }

      it { should eq 1000 }
    end
  end

  def assert_config_default(option, default_value, config = nil)
    config ||= Honeybadger::Configuration.new
    expect(config.send(option)).to eq default_value
  end

  def assert_config_overridable(option, value = 'a value')
    config = Honeybadger::Configuration.new
    config.send(:"#{option}=", value)
    expect(config.send(option)).to eq value
  end

  def assert_appends_value(option, &block)
    config = Honeybadger::Configuration.new
    original_values = config.send(option).dup
    block ||= lambda do |c|
      new_value = 'hello'
      c.send(option) << new_value
      new_value
    end
    new_value = block.call(config)
    expect(original_values + [new_value]).to eq config.send(option)
  end

  def assert_replaces(option, setter)
    config = Honeybadger::Configuration.new
    new_value = 'hello'
    config.send(setter, [new_value])
    expect(config.send(option)).to eq [new_value]
    config.send(setter, new_value)
    expect(config.send(option)).to eq [new_value]
  end
end
