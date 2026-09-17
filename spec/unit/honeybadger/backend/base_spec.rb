require "honeybadger/backend/base"
require "honeybadger/config"

describe Honeybadger::Backend::Response do
  context "when successful" do
    subject { described_class.new(201) }
    its(:error) { should be_nil }
  end

  def http_response(code, retry_after: nil)
    response = Net::HTTPResponse.new("1.1", code.to_s, "")
    response["Retry-After"] = retry_after.to_s if retry_after
    allow(response).to receive(:body).and_return("")
    response
  end

  describe "#retry_after" do
    context "with Retry-After header" do
      subject { described_class.new(http_response(429, retry_after: 30)) }
      its(:retry_after) { should eq 30 }
    end

    context "without Retry-After header" do
      subject { described_class.new(429) }
      its(:retry_after) { should be_nil }
    end

    context "with Retry-After: 0" do
      subject { described_class.new(http_response(429, retry_after: 0)) }
      its(:retry_after) { should be_nil }
    end

    context "with non-numeric Retry-After header" do
      subject { described_class.new(http_response(429, retry_after: "abc")) }
      its(:retry_after) { should be_nil }
    end
  end

  describe "#retryable?" do
    context "429 with short retry_after" do
      subject { described_class.new(http_response(429, retry_after: 30)) }
      it { should be_retryable }
    end

    context "503 with short retry_after" do
      subject { described_class.new(http_response(503, retry_after: 30)) }
      it { should be_retryable }
    end

    context "429 at boundary (300)" do
      subject { described_class.new(http_response(429, retry_after: 300)) }
      it { should be_retryable }
    end

    context "429 over boundary (301)" do
      subject { described_class.new(http_response(429, retry_after: 301)) }
      it { should_not be_retryable }
    end

    context "429 without retry_after" do
      subject { described_class.new(429) }
      it { should_not be_retryable }
    end

    context "201 with retry_after" do
      subject { described_class.new(http_response(201, retry_after: 30)) }
      it { should_not be_retryable }
    end
  end

  describe "#error_message" do
    context "when code is 403 and body contains a JSON error" do
      let(:response) { described_class.new(403, %({"error":"api key denied: Quota exceeded"}\n)) }

      it "returns the server error" do
        expect(response.error_message).to eq("api key denied: Quota exceeded")
      end
    end

    context "when code is 403 and body is not valid JSON" do
      let(:response) { described_class.new(403, "Forbidden") }

      it "falls back to the friendly 403 error" do
        expect(response.error_message).to match(/API key is invalid/i)
      end
    end
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
