require 'spec_helper'

describe Honeybadger::Payload do
  its(:max_depth) { should eq 20 }

  context "when max_depth option is passed to #initialize" do
    subject { described_class.new({}, :max_depth => 5) }
    its(:max_depth) { should eq 5 }

    context "when initialized with a bad object" do
      it "raises ArgumentError" do
        expect { described_class.new([], :max_depth => 5) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#sanitize" do
    let(:deep_hash) { {}.tap {|h| 30.times.each {|i| h = h[i.to_s] = {:string => 'string'} }} }
    let(:expected_hash) { {}.tap {|h| max_depth.times.each {|i| h = h[i.to_s] = {:string => 'string'} }} }
    let(:sanitized_hash) { described_class.new(deep_hash, :max_depth => max_depth) }
    let(:max_depth) { 10 }

    it "truncates nested hashes to max_depth" do
      expect(sanitized_hash).to eq(expected_hash)
    end
  end
end
