require 'honeybadger/config'

describe Honeybadger::Config::Yaml do
  subject { described_class.new(FIXTURES_PATH.join('honeybadger.yml'), env) }
  let(:env) { 'production' }

  it { should be_a Hash }

  context "when options are nested" do
    it "converts deeply nested options to dotted hash syntax" do
      should eq({:enabled => true, :api_key => 'asdf', :'foo.bar' => 'baz', :'foo.baz' => 'other', :'a.really.deeply.nested' => 'option', :'production.api_key' => 'asdf'})
    end
  end

  context "when an environment namespace is present" do
    it "prioritizes the namespace" do
      expect(subject[:api_key]).to eq 'asdf'
    end

    context "and the environment collides with an option namespace" do
      let(:env) { 'foo' }

      it "prioritizes the environment namespace" do
        expect(subject[:bar]).to eq 'baz'
        expect(subject[:baz]).to eq 'other'
      end
    end

    context "and the environment collides with an option name" do
      let(:env) { 'api_key' }

      it "prioritizes the option name" do
        expect(subject[:api_key]).to eq 'zxcv'
      end
    end
  end

  context "when an environment namespace is not present" do
    subject { described_class.new(FIXTURES_PATH.join('honeybadger.yml'), 'foo') }

    it "falls back to the top level namespace" do
      expect(subject[:api_key]).to eq 'zxcv'
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

  context "when an unknown error occurs" do
    before do
      allow(YAML).to receive(:load).and_raise(RuntimeError)
    end

    it "raises a ConfigError" do
      expect { subject }.to raise_error(Honeybadger::Config::ConfigError)
    end
  end
end
