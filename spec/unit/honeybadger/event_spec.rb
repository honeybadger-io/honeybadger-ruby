require "honeybadger/event"
require "timecop"

describe Honeybadger::Event do
  let(:event_type) { "event_type" }
  let(:payload) { {} }

  subject { described_class.new(event_type, payload) }

  describe "initialize" do
    context "event_type is passed as string" do
      let(:event_type) { "action" }
      let(:payload) { {} }

      its(:event_type) { should eq "action" }
      its(:payload) { should eq payload }
    end

    context "event_type is passed as part of payload" do
      subject { described_class.new(event_type) }

      let(:event_type) { {event_type: "action"} }

      its(:event_type) { should eq "action" }
      its(:payload) { should eq({event_type: "action"}) }
    end

    context "event_type is passed as a Hash with a second payload argument" do
      subject { described_class.new(event_type_or_payload, payload) }

      let(:event_type_or_payload) { {event_type: "action", caller_key: "caller"} }
      let(:payload) { {environment: "production", hostname: "host"} }

      its(:event_type) { should eq "action" }

      it "merges the second payload into the first, with the first winning on conflicts" do
        expect(subject.payload).to eq({
          event_type: "action",
          caller_key: "caller",
          environment: "production",
          hostname: "host"
        })
      end

      context "when the same key appears in both arguments" do
        let(:event_type_or_payload) { {event_type: "action", environment: "staging"} }
        let(:payload) { {environment: "production"} }

        it "the first argument takes precedence" do
          expect(subject.payload[:environment]).to eq("staging")
        end
      end
    end
  end

  describe "ts" do
    before { Timecop.freeze }
    after { Timecop.unfreeze }

    its(:ts) { should eq Time.now.utc.strftime("%FT%T.%LZ") }
  end

  describe "halted" do
    context "halt! is not called" do
      its(:halted?) { should be false }
    end

    context "halt! is called" do
      before { subject.halt! }
      its(:halted?) { should be true }
    end
  end

  describe "as_json" do
    let(:event_type) { "action" }
    let(:payload) { {data1: 1} }

    before { Timecop.freeze }
    after { Timecop.unfreeze }

    its(:as_json) { should eq({event_type: "action", ts: Time.now.utc.strftime("%FT%T.%LZ"), data1: 1}) }
  end
end
