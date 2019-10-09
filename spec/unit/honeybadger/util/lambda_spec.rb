require 'honeybadger/util/lambda'

describe Honeybadger::Util::Lambda do
  subject { described_class }

  before do
    allow(ENV).to receive(:[])
  end

  describe ".normalized_data" do
    it "includes all HTTP headers" do
      expect(ENV).to receive(:[]).twice.with("AWS_REGION").and_return("westeros")
      expect(ENV).to receive(:[]).twice.with("AWS_EXECUTION_ENV").and_return("Ruby")
      expect(subject.normalized_data).to eq({
        "runtime" => "Ruby",
        "region" => "westeros"
      })
    end
  end
end
