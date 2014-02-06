require 'spec_helper'

describe Honeybadger::Dependency do
  let(:dependency) { Honeybadger::Dependency.new }
  subject          { dependency }

  before { Honeybadger::Dependency.stub(:instances).and_return([]) }

  describe ".register" do
    it "returns a new dependency" do
      instance = double()
      Honeybadger::Dependency.stub(:new).and_return(instance)
      expect(Honeybadger::Dependency.register {}).to eq [instance]
    end

    it "registers a new dependency" do
      expect { Honeybadger::Dependency.register {} }.to change(described_class, :instances).from([]).to([kind_of(Honeybadger::Dependency)])
    end
  end

  describe ".inject!" do
    it "injects all satisfied instances" do
      Honeybadger::Dependency.instances.replace([mock_dependency, mock_dependency])
      Honeybadger::Dependency.inject!
    end

    it "skips all unsatisfied instances" do
      Honeybadger::Dependency.instances.replace([mock_dependency(false), mock_dependency(false)])
      Honeybadger::Dependency.inject!
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

  describe "#injection" do
    let(:block) { Proc.new {} }

    it "returns an Array of injections" do
      expect(subject.injection(&block)).to eq [block]
    end

    it "registers a new injection" do
      expect { subject.injection(&block) }.to change(subject, :injections).from([]).to([block])
    end
  end

  describe "#ok?" do
    subject { dependency.ok? }

    context "when not injected yet" do
      it { should be_true }
    end

    context "when already injected" do
      before { dependency.inject! }

      it { should be_false }
    end

    context "all requirements are met" do
      before do
        3.times { dependency.requirement { true } }
      end
    end

    context "some requirements fail" do
      before do
        3.times { dependency.requirement { true } }
        dependency.requirement { false }
      end

      it { should be_false }
    end
  end

  describe "#inject!" do
    it "calls injections" do
      dependency.injections.replace([mock_injection, mock_injection])
      dependency.inject!
    end
  end

  def mock_dependency(ok = true)
    double(:ok? => ok).tap { |d| d.send(ok ? :should_receive : :should_not_receive, :inject!) }
  end

  def mock_injection(positive = true)
    double().tap { |d| d.send(positive ? :should_receive : :should_not_receive, :call) }
  end
end
