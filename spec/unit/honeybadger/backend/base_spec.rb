require "honeybadger/backend/base"
require "honeybadger/config"

describe Honeybadger::Backend::Response do
  context "when successful" do
    subject { described_class.new(201) }
    its(:error) { should be_nil }
  end

  context "when unsuccessful" do
    subject { described_class.new(403, body) }

    context "body is missing" do
      let(:body) { nil }
      its(:error) { should be_nil }
    end

    context "body is empty" do
      let(:body) { "" }
      its(:error) { should be_nil }
    end

    context "body is valid JSON" do
      let(:body) { %({"error":"badgers"}) }
      its(:error) { should eq "badgers" }

      context "but invalid object" do
        let(:body) { %([{"error":"badgers"}]) }
        its(:error) { should be_nil }
      end
    end

    context "body is invalid JSON" do
      let(:body) { %({"error":"badgers") }
      its(:error) { should be_nil }
    end
  end

  context "with Retry-After header" do
    let(:response) do
      mock_response = double("Net::HTTPResponse",
        code: "429",
        body: "",
        message: "Too Many Requests")
      # Make the mock respond to is_a? to return true for Net::HTTPResponse
      allow(mock_response).to receive(:is_a?).with(Net::HTTPResponse).and_return(true)
      allow(mock_response).to receive(:[]).with("Retry-After").and_return(retry_after_value)
      mock_response
    end

    subject { described_class.new(response) }

    context "when Retry-After is not present" do
      let(:retry_after_value) { nil }

      it "returns nil" do
        expect(subject.retry_after_seconds).to be_nil
      end
    end

    context "when Retry-After is an integer (seconds)" do
      let(:retry_after_value) { "60" }

      it "returns the number of seconds" do
        expect(subject.retry_after_seconds).to eq(60)
      end
    end

    context "when Retry-After is an HTTP date" do
      let(:retry_after_value) { "Wed, 21 Oct 2015 07:28:00 GMT" }

      it "returns the number of seconds until that time" do
        # Mock Time.now to return a fixed time for predictable testing
        allow(Time).to receive(:now).and_return(Time.parse("2015-10-21 07:27:00 GMT"))
        expect(subject.retry_after_seconds).to eq(60)
      end
    end

    context "when Retry-After has invalid format" do
      let(:retry_after_value) { "invalid-date" }

      it "returns nil" do
        expect(subject.retry_after_seconds).to be_nil
      end
    end
  end
end

describe Honeybadger::Backend::Base do
  let(:config) { Honeybadger::Config.new }

  subject { described_class.new(config) }

  it { should respond_to :notify }
  it { should respond_to :event }

  describe "#notify" do
    it "raises NotImplementedError" do
      expect { subject.notify(:notices, double("Notice")) }.to raise_error NotImplementedError
    end
  end

  describe "#check_in" do
    it "raises NotImplementedError" do
      expect { subject.check_in(10) }.to raise_error NotImplementedError
    end
  end

  describe "#track_deployment" do
    it "defers the request to notify with the feature set as deploys" do
      opts = double(:opts)
      expect(subject).to receive(:notify).with(:deploys, opts)
      subject.track_deployment(opts)
    end
  end
end
