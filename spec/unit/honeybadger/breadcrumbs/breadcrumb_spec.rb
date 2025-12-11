require "timecop"
require "honeybadger/breadcrumbs/ring_buffer"

RSpec.describe Honeybadger::Breadcrumbs::Breadcrumb do
  let(:category) { :test }
  let(:message) { "A test message" }
  let(:metadata) { {a: "foo"} }

  subject { described_class.new(category: category, message: message, metadata: metadata) }

  before { Timecop.freeze }
  after { Timecop.return }

  its(:category) { should eq(category) }
  its(:message) { should eq(message) }
  its(:metadata) { should eq(metadata) }
  its(:timestamp) { should eq(Time.now.utc) }

  describe "#to_h" do
    it "outputs hash data" do
      expect(subject.to_h).to eq({
        category: category,
        message: message,
        metadata: metadata,
        timestamp: Time.now.utc.iso8601(3)
      })
    end
  end

  describe "#comparable" do
    it "can be compared on hash content" do
      expect(subject == subject.dup).to be(true)
    end
  end

  describe "#ignore!" do
    it "can be deactivated" do
      expect(subject).to be_active
      subject.ignore!
      expect(subject).to_not be_active
    end
  end
end
