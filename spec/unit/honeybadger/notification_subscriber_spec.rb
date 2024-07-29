# encoding: utf-8

require 'honeybadger/notification_subscriber'

describe Honeybadger::ActiveSupportCacheMultiSubscriber do
  module ActiveSupport
    module Cache; end
  end

  context "with a cache_write_multi.active_support payload" do
    let(:payload) do
      obj = Object.new
      {
        key: {'one' => 'data', 'object.cache_key' => obj },
        store: 'cache-store-name'
      }
    end

    before do
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:key].keys[0]).and_return('one')
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:key].keys[1]).and_return('foo/bar')
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
        key: ['one', Object.new],
        hits: ['one'],
        store: 'cache-store-name',
        super_operation: :fetch_multi
      }
    end

    before do
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:key][0]).and_return('one')
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:key][1]).and_return('foo/bar')
      allow(::ActiveSupport::Cache).to receive(:expand_cache_key).with(payload[:hits][0]).and_return('one')
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
