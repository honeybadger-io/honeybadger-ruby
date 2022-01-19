require 'honeybadger/config'

describe Honeybadger::Config::Yaml do
  subject { described_class.new(path, env) }
  let(:path) { FIXTURES_PATH.join('honeybadger.yml') }
  let(:env) { 'production' }

  it { should be_a Hash }

  context "when options are nested" do
    it "converts deeply nested options to dotted hash syntax" do
      expect(subject[:'a.really.deeply.nested']).to eq 'option'
    end
  end

  context "when an environment namespace is present" do
    it "prioritizes the namespace" do
      expect(subject[:api_key]).to eq 'asdf'
    end

    context "and the environment collides with an option name" do
      let(:env) { 'api_key' }

      it "prioritizes the option name" do
        expect(subject[:api_key]).to eq 'zxcv'
      end
    end

    context "and the environment collides with an option namespace" do
      let(:env) { 'logging' }
      let(:yaml) { <<-YAML }
api_key: "cobras"
top: true
logging:
  api_key: "badgers"
  path: "log/my.log"
  level: "DEBUG"
      YAML

      before do
        allow(path).to receive(:read).and_return(yaml)
      end

      it "merges all the options" do
        expect(subject[:'logging.path']).to eq 'log/my.log'
        expect(subject[:'logging.level']).to eq 'DEBUG'
        expect(subject[:'logging.api_key']).to eq 'badgers'
        expect(subject[:api_key]).to eq 'badgers'
        expect(subject[:top]).to eq true
      end
    end
  end

  context "when an environment namespace is not present" do
    subject { described_class.new(FIXTURES_PATH.join('honeybadger.yml'), 'foo') }

    it "falls back to the top level namespace" do
      expect(subject[:api_key]).to eq 'zxcv'
    end
  end

  context "when ERB is used" do
    it "evaluates ERB" do
      expect(subject[:erb]).to eq 'erb!'
    end
  end

  context "when file is not found" do
    it "raises a ConfigError" do
      expect { described_class.new('foo.yml') }.to raise_error(Honeybadger::Config::ConfigError)
    end
  end

  context "when file is a directory" do
    it "raises a ConfigError" do
      expect { described_class.new(FIXTURES_PATH) }.to raise_error(Honeybadger::Config::ConfigError)
    end
  end

  context "when the YAML content is" do
    before { allow(path).to receive(:read).and_return(yaml) }

    context "nil" do
      let(:yaml) { '---' }
      it { should eq({}) }
    end

    context "empty" do
      let(:yaml) { '' }
      it { should eq({}) }
    end

    context "invalid" do
      let(:yaml) { 'foo' }
      specify { expect { subject }.to raise_error(Honeybadger::Config::ConfigError) }
    end

    context "valid" do
      let(:yaml) { 'foo: bar' }
      it { should eq({ foo: 'bar' }) }
    end
  end

  context "when the YAML content contains a Ruby class" do
    before { allow(path).to receive(:read).and_return(yaml) }
    let(:yaml) { "foo: !ruby/regexp '/credit_card/i'" }

    it { should eq({ foo: /credit_card/i }) }
  end

  context "when an unknown error occurs" do
    before do
      method = YAML.respond_to?(:unsafe_load) ? :unsafe_load : :load
      allow(YAML).to receive(method).and_raise(RuntimeError)
    end

    it "re-raises the exception" do
      expect { subject }.to raise_error(Honeybadger::Config::ConfigError)
    end
  end

  context "when an error occurs in ERB" do
    let(:config_path) { FIXTURES_PATH.join('honeybadger.yml') }
    let(:yaml) { <<-YAML }
---
api_key: "<%= MyApp.config.nonexistant_var %>"
YAML

    before do
      allow(config_path).to receive(:read).and_return(yaml)
    end

    it "raises a config error" do
      expect { described_class.new(config_path) }.to raise_error(Honeybadger::Config::ConfigError)
    end

    it "raises an exception with a helpful backtrace", if: RUBY_PLATFORM !~ /java/ do
      begin
        described_class.new(config_path)
      rescue => e
        expect(e.backtrace[0]).to start_with(config_path.to_s)
      end
    end
  end
end
