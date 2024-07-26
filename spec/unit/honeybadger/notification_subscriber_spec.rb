# encoding: utf-8

require 'honeybadger/notification_subscriber'

describe Honeybadger::ActiveSupportCacheMultiSubscriber do
  class Poro
    attr_reader :attribute1, :attribute2

    def initialize
      @attribute1 = "foo"
      @attribute2 = "bar"
    end

    def cache_key
      "#{attribute1}/#{attribute2}"
    end
  end

  context "with a cache_write_multi.active_support payload" do
    let(:payload) do
      obj = Poro.new
      {
        key: {'one' => 'data', obj.cache_key => obj },
        store: 'cache-store-name'
      }
    end

    subject { described_class.new.format_payload(payload) }

    it "returns a payload with all keys expanded and without cache values" do
      expect(subject).to be_a(Hash)
      expect(subject[:key]).to eq(%w(one foo/bar))
      expect(subject[:store]).to eq('cache-store-name')
    end
  end

  context "with a cache_read_multi.active_support payload" do
    let(:payload) do
      {
        key: ['one', Poro.new],
        hits: ['one'],
        store: 'cache-store-name',
        super_operation: :fetch_multi
      }
    end

    subject { described_class.new.format_payload(payload) }

    it "returns a payload with all keys expanded" do
      expect(subject).to be_a(Hash)
      expect(subject[:key]).to eq(%w(one foo/bar))
      expect(subject[:hits]).to eq(%w(one))
      expect(subject[:store]).to eq('cache-store-name')
      expect(subject[:super_operation]).to eq(:fetch_multi)
    end
  end
end
