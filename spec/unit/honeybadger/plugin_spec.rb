describe Honeybadger::Plugin::CALLER_FILE do
  it { should_not match "/foo/bar" }
  it { should match "/foo/bar:32" }
  it { should match "D:/foo/bar:32" }

  describe "unix match" do
    subject { described_class.match("/foo/bar:32") }
    specify { expect(subject.size).to eq(3) }
    specify { expect(subject[1]).to eq("/foo/bar") }
    specify { expect(subject[2]).to eq(":32") }
  end

  describe "windows match" do
    subject { described_class.match("D:/foo/bar:32") }
    specify { expect(subject.size).to eq(3) }
    specify { expect(subject[1]).to eq("/foo/bar") }
    specify { expect(subject[2]).to eq(":32") }
  end
end

describe Honeybadger::Plugin do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }
  let(:plugin) { Honeybadger::Plugin.new(:testing) }
  subject { plugin }

  before do
    # We're messing with global state here, so we need to make sure it's not
    # permanent. When testing the plugins themselves, we should ensure that we
    # are never calling `Plugin#load!` globally -- use
    # `Plugin.instances[:plugin_name]#load!` instead.
    allow(Honeybadger::Plugin).to receive(:instances).and_return({})
  end

  describe ".register" do
    it "returns a new plugin" do
      instance = double()
      allow(Honeybadger::Plugin).to receive(:new).and_return(instance)
      expect(Honeybadger::Plugin.register {}).to eq instance
    end

    it "registers a new plugin without a name" do
      expect(described_class.instances).to be_empty
      Honeybadger::Plugin.register {}
      expect(described_class.instances[:'plugin_spec']).to be_a Honeybadger::Plugin
    end

    it "registers a new plugin with a name" do
      expect(described_class.instances).to be_empty
      Honeybadger::Plugin.register(:foo) {}
      expect(described_class.instances[:'foo']).to be_a Honeybadger::Plugin
    end

    it "registers a new plugin with a String name" do
      expect(described_class.instances).to be_empty
      Honeybadger::Plugin.register('foo') {}
      expect(described_class.instances[:'foo']).to be_a Honeybadger::Plugin
    end
  end

  describe ".load!" do
    it "loads all satisfied instances" do
      Honeybadger::Plugin.instances.replace({:one => mock_plugin, :two => mock_plugin})
      Honeybadger::Plugin.load!(config)
    end

    it "skips all unsatisfied instances" do
      Honeybadger::Plugin.instances.replace({:one => mock_plugin(false), :two => mock_plugin(false)})
      Honeybadger::Plugin.load!(config)
    end

    context "when skipped by configuration" do
      before do
        config[:plugins] = ['two', :three]
        Honeybadger::Plugin.instances.replace({:one => mock_plugin(true, false), :two => mock_plugin(true), :three => mock_plugin(true)})
      end

      it "skips instances" do
        Honeybadger::Plugin.load!(config)
      end

      it "logs skipped instances" do
        allow(config.logger).to receive(:debug)
        expect(config.logger).to receive(:debug).with(/reason=disabled/i).once
        Honeybadger::Plugin.load!(config)
      end
    end
  end

  describe "#requirement" do
    let(:block) { Proc.new {} }

    it "returns and Array of requirements" do
      expect(subject.requirement(&block)).to eq [block]
    end

    it "registers a new requirement" do
      expect { subject.requirement(&block) }.to change(subject, :requirements).from([]).to([block])
    end
  end

  describe "#execution" do
    let(:block) { Proc.new {} }

    it "returns an Array of executions" do
      expect(subject.execution(&block)).to eq [block]
    end

    it "registers a new execution" do
      expect { subject.execution(&block) }.to change(subject, :executions).from([]).to([block])
    end
  end

  describe "#ok?" do
    subject { plugin.ok?(config) }

    context "all requirements are met" do
      before do
        3.times { plugin.requirement { true } }
      end

      it { should eq true }
    end

    context "some requirements fail" do
      before do
        3.times { plugin.requirement { true } }
        plugin.requirement { false }
      end

      it { should eq false }
    end

    context "some requirements error" do
      before do
        plugin.requirement { true }
        plugin.requirement { fail 'oops!' }
      end

      it { should eq false }

      it "logs the failure" do
        expect(config.logger).to receive(:error).with(/oops!/).once
        plugin.ok?(config)
      end
    end
  end

  describe "#load!" do
    context "when already loaded" do
      before { plugin.load!(config) }

      it "doesn't call executions" do
        plugin.executions.replace([mock_execution(false), mock_execution(false)])
        plugin.load!(config)
      end

      it "logs already loaded" do
        expect(config.logger).to receive(:debug).with(/reason=loaded/i)
        plugin.load!(config)
      end
    end

    it "calls executions" do
      plugin.executions.replace([mock_execution, mock_execution])
      plugin.load!(config)
    end

    it "logs installation" do
      expect(config.logger).to receive(:debug).with(/testing/i)
      plugin.load!(config)
    end

    context "some executions fail" do
      before do
        failing_execution = Proc.new { fail 'oh noes!' }
        plugin.executions.replace([mock_execution, failing_execution, mock_execution(false)])
      end

      it "halts execution silently" do
        expect { plugin.load!(config) }.not_to raise_error
      end

      it "logs the failure" do
        expect(config.logger).to receive(:error).with(/oh noes!/).once
        plugin.load!(config)
      end

      it "marks the plugin as loaded" do
        expect { plugin.load!(config) }.to change(plugin, :loaded?).from(false).to(true)
      end
    end
  end

  def mock_plugin(ok = true, expected = ok)
    plugin, expecting = Honeybadger::Plugin.new(:testing), double()
    expect(expecting).send(expected ? :to : :not_to, receive(:foo))
    allow(plugin).to receive(:ok?).and_return(ok)
    plugin.executions << Proc.new { expecting.foo }
    plugin
  end

  def mock_execution(positive = true)
    expecting = double()
    expect(expecting).send(positive ? :to : :not_to, receive(:foo))
    Proc.new { expecting.foo }
  end
end
