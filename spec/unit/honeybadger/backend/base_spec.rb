require "honeybadger/backend/base"
require "honeybadger/config"

describe Honeybadger::Backend::Response do
  context "when successful" do
    subject { described_class.new(201) }
    its(:error) { should be_nil }
  end

  describe "#retry_after" do
    context "with Retry-After header" do
      subject { build_response(429, retry_after: 30) }
      its(:retry_after) { should eq 30 }
    end

    context "without Retry-After header" do
      subject { described_class.new(429) }
      its(:retry_after) { should be_nil }
    end

    context "with Retry-After: 0" do
      subject { build_response(429, retry_after: 0) }
      its(:retry_after) { should be_nil }
    end

    context "with non-numeric Retry-After header" do
      subject { build_response(429, retry_after: "abc") }
      its(:retry_after) { should be_nil }
    end
  end

  describe "#limit_reason" do
    context "with mixed case and surrounding whitespace" do
      subject { build_response(429, limit_reason: " Overloaded ") }
      its(:limit_reason) { should eq "overloaded" }
    end

    context "without Honeybadger-Limit-Reason header" do
      subject { build_response(429) }
      its(:limit_reason) { should be_nil }
    end
  end

  describe "#retryable?" do
    # code, limit_reason, retry_after, expected
    [
      [502, nil, nil, true],
      [503, nil, nil, true],
      [504, nil, nil, true],
      [503, nil, 60, true],
      [503, nil, 61, false],
      [429, "overloaded", nil, true],
      [429, "overloaded", 30, true],
      [429, "overloaded", 61, false],
      [429, "rate_limited", 30, false],
      [429, "quota_exceeded", 30, false],
      [429, nil, 30, false],
      [500, nil, nil, false],
      [201, nil, 30, false]
    ].each do |code, limit_reason, retry_after, expected|
      context "#{code} limit_reason=#{limit_reason.inspect} retry_after=#{retry_after.inspect}" do
        subject { build_response(code, limit_reason: limit_reason, retry_after: retry_after) }
        its(:retryable?) { should eq expected }
      end
    end
  end

  describe "#reject_interval" do
    # code, limit_reason, retry_after, expected
    [
      [429, "rate_limited", 30, 30],
      [429, "quota_exceeded", 1800, 1800],
      [429, nil, nil, 60],
      [503, nil, 600, 600],
      [503, nil, nil, nil],
      [503, nil, 30, nil],
      [429, "overloaded", 30, nil],
      [401, nil, 300, 300],
      [401, nil, nil, 3600],
      [403, nil, nil, 3600],
      [413, nil, nil, nil],
      [201, nil, nil, nil]
    ].each do |code, limit_reason, retry_after, expected|
      context "#{code} limit_reason=#{limit_reason.inspect} retry_after=#{retry_after.inspect}" do
        subject { build_response(code, limit_reason: limit_reason, retry_after: retry_after) }
        its(:reject_interval) { should eq expected }
      end
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
