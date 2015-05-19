require 'honeybadger/util/request_payload'

class TestSanitizer
  def sanitize(data)
    data
  end

  def filter_url(string)
    string
  end
end

describe Honeybadger::Util::RequestPayload do
  let(:sanitizer) { TestSanitizer.new }

  Honeybadger::Util::RequestPayload::DEFAULTS.each_pair do |key, value|
    it "defaults #{ key } to default value" do
      expect(subject[key]).to eq value
    end
  end

  it "can be intiailized with a hash" do
    subject = described_class.new({ component: 'foo' })
    expect(subject[:component]).to eq 'foo'
  end

  it "rejects invalid keys" do
    subject = described_class.new({ foo: 'foo' })
    expect(subject).not_to have_key(:foo)
  end

  it "defaults nil keys" do
    subject = described_class.new({ params: nil })
    expect(subject[:params]).to eq({})
  end

  it "injects the sanitizer" do
    subject = described_class.new({ sanitizer: sanitizer })
    expect(subject).not_to have_key(:sanitizer)
    expect(subject.sanitizer).to eq sanitizer
  end

  describe "#to_hash" do
    it "sanitizes payload with injected sanitizer" do
      subject = described_class.new({ sanitizer: sanitizer })
      expect(sanitizer).to receive(:sanitize).exactly(Honeybadger::Util::RequestPayload::KEYS.size).times
      expect(subject.to_hash).to be_a Hash
    end

    it "sanitizes the url key" do
      sanitizer = TestSanitizer.new
      subject = described_class.new({ sanitizer: sanitizer, url: 'foo/bar' })
      expect(sanitizer).to receive(:filter_url).with('foo/bar')
      expect(subject.to_hash).to be_a Hash
    end
  end

  describe "#to_json" do
    it "converts #to_hash to JSON" do
      original = subject.to_hash
      result = JSON.parse(subject.to_json)

      expect(result.size).to eq original.size
      subject.to_hash.each_pair do |k,v|
        expect(result[k.to_s]).to eq v
      end
    end
  end
end
