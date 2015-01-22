require 'honeybadger/agent/trace_collection'

describe Honeybadger::Agent::TraceCollection do
  it { should respond_to :size }
  it { should respond_to :empty? }
  it { should respond_to :to_a }
  it { should respond_to :push }
  it { should respond_to :map }

  describe "#push" do
    let(:instance) { described_class.new }
    let(:old) { double('Honeybadger::Trace', key: :foo, duration: 4000) }

    before do
      instance.push(old)
    end

    context "when the trace doesn't exist" do
      it "adds it to the collection" do
        expect(instance.to_a).to eq [old]
      end
    end

    context "when the trace exists" do
      let(:new) { double('Honeybadger::Trace', key: :foo, duration: duration) }

      before do
        instance.push(new)
      end

      context "and the new trace has a longer duration" do
        let(:duration) { 5000 }

        it "keeps the new" do
          expect(instance.to_a).to eq [new]
        end
      end

      context "and the new trace has a shorter duration" do
        let(:duration) { 3000 }

        it "keeps the old" do
          expect(instance.to_a).to eq [old]
        end
      end
    end
  end
end
