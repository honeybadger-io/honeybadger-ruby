require 'timecop'
require 'honeybadger/breadcrumbs/ring_buffer'

describe Breadcrumbs::Crumb do
  let(:category) { :test }
  let(:message) { "A test message" }
  let(:metadata) {{ a: "foo" }}

  subject { described_class.new(category: category, message: message, metadata: metadata) }

  before { Timecop.freeze }
  after { Timecop.return }

  its(:category) { should eq(category) }
  its(:message) { should eq(message) }
  its(:metadata) { should eq(metadata) }
  its(:timestamp) { should eq(DateTime.now) }

  describe "#to_hash" do
    it "outputs hash data" do
      expect(subject.to_hash).to eq({
        "category" => category,
        "message" => message,
        "metadata" => metadata,
        "timestamp" => DateTime.now
      })
    end
  end
end
