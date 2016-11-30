# encoding: utf-8

require 'honeybadger/util/sanitizer'

describe Honeybadger::Util::Sanitizer do
  its(:max_depth) { should eq 20 }
  its(:filters) { should be_nil }

  context "when max_depth option is passed to #initialize" do
    subject { described_class.new(max_depth: 5) }
    its(:max_depth) { should eq 5 }
  end

  context "when filters option is passed to #initialize" do
    FILTER_ARRAY = ['foo'].freeze

    subject { described_class.new(filters: FILTER_ARRAY) }
    its(:filters) { should_not be_empty }
  end

  describe "::sanitize_string" do
    it "converts to string before sanitizing" do
      expect(Honeybadger::Util::Sanitizer.sanitize_string(nil)).to eq('')
    end

    it "returns the String argument when already valid" do
      foo = "foo"
      expect(Honeybadger::Util::Sanitizer.sanitize_string(foo)).to be(foo)
    end
  end

  describe "#sanitize" do
    let(:deep_hash) { {}.tap {|h| 30.times.each {|i| h = h[i.to_s] = {:string => 'string'} }} }
    let(:expected_hash) { {}.tap {|h| max_depth.times.each {|i| h = h[i.to_s] = (i < max_depth-1 ? {:string => 'string'} : '[max depth reached]') }} }
    let(:sanitized_hash) { described_class.new(max_depth: max_depth).sanitize(deep_hash) }
    let(:max_depth) { 10 }

    it "truncates nested hashes to max_depth" do
      expect(sanitized_hash['0']).to eq(expected_hash['0'])
    end

    it "does not allow infinite recursion" do
      hash = {:a => :a}
      hash[:hash] = hash
      payload = described_class.new.sanitize(request: {params: hash})
      expect(payload[:request][:params][:hash]).to eq "[possible infinite recursion halted]"
    end

    it "converts unserializable objects to strings" do
      assert_serializes(:request, :parameters)
      assert_serializes(:request, :cgi_data)
      assert_serializes(:request, :session_data)
      assert_serializes(:request, :local_variables)
    end

    it "ensures #to_hash is called on objects that support it" do
      expect { described_class.new(:session => { :object => double(:to_hash => {}) }) }.not_to raise_error
    end

    it "ensures #to_ary is called on objects that support it" do
      expect { described_class.new(:session => { :object => double(:to_ary => {}) }) }.not_to raise_error
    end

    it "allocates under 1/2 objects vs. the original hash.", if: defined?(AllocationStats) do
      o = AllocationStats.trace { deep_hash }
      expect { sanitized_hash }.to allocate_under((o.new_allocations.size/2)).objects
    end

    context "with bad encodings" do
      let(:string) { 'hello ümlaut' }
      let(:binary) { string.dup.force_encoding(Encoding::BINARY) }
      let(:windows) { string.dup.force_encoding(Encoding::Windows_31J) }
      let(:invalid) { (100..1000).to_a.pack('c*').force_encoding('utf-8') }

      it "generates JSON with incompatible encodings" do
        expect { described_class.new.sanitize('string' => binary).to_json }.not_to raise_error
      end

      it "generates JSON with bad encodings" do
        expect { described_class.new.sanitize('string' => invalid).to_json }.not_to raise_error
      end

      it "converts to utf-8 when invalid" do
        expect(described_class.new.sanitize('string' => invalid)['string'].encoding).to eq Encoding::UTF_8
      end

      it "converts to utf-8 when binary" do
        expect(described_class.new.sanitize('string' => binary)['string']).to eq 'hello ??mlaut'
      end

      it "converts to UTF-8 when otherwise valid" do
        expect(described_class.new.sanitize('string' => windows)['string']).to eq windows.encode!(Encoding::UTF_8)
      end
    end

    context "with filters" do
      subject { described_class.new(filters: filters).sanitize(original) }

      let!(:filters) { ["abc", :def, /private/, /^foo_.*$/] }

      let!(:original) do
        { 'abc' => "123", 'def' => "456", 'ghi' => "789", 'nested' => { 'abc' => '100' },
          'something_with_abc' => 'match the entire string', 'private_param' => 'prra',
          'foo_param' => 'bar', 'not_foo_param' => 'baz', 'nested_foo' => { 'foo_nested' => 'bla'} }
      end

      let!(:filtered) do
        {'abc'    => '[FILTERED]',
         'def'    => '[FILTERED]',
         'something_with_abc' => '[FILTERED]',
         'ghi'    => '789',
         'nested' => { 'abc' => '[FILTERED]' },
         'private_param' => '[FILTERED]',
         'foo_param' => '[FILTERED]',
         'not_foo_param' => 'baz',
         'nested_foo' => { 'foo_nested' => '[FILTERED]'}}
      end

      it "filters the hash" do
        should eq filtered
      end

      it "allocates approximately same number of objects as without filters.", if: defined?(AllocationStats) do
        o = AllocationStats.trace { described_class.new.sanitize(original) }
        expect { subject }.to allocate_under(o.new_allocations.size+8).objects
      end
    end
  end

  describe '#filter_url' do
    subject { described_class.new.filter_url(url) }

    context 'malformed query' do
      let(:url) { 'https://www.honeybadger.io/?foobar12' }
      it { should eq url }
    end

    context 'no query' do
      let(:url) { 'https://www.honeybadger.io' }
      it { should eq url }
    end

    context 'malformed url' do
      let(:url) { 'http s ! honeybadger' }
      before { expect { URI.parse(url) }.to raise_error(URI::InvalidURIError) }
      it { should eq url }
    end

    context 'complex url' do
      let(:url) { 'https://foo:bar@www.honeybadger.io:123/asdf/?foo=1&bar=2&baz=3' }
      it { should eq url }
    end
  end

  describe '#filter_cookies' do
    let!(:filters) { ["abc", :def, /private/] }

    let!(:cookies) {"abc=123; def=456; ghi=789; private_param=prra"}
    let(:filtered_cookies) {"abc=[FILTERED]; def=[FILTERED]; ghi=789; private_param=[FILTERED]"}
    subject { described_class.new(filters: filters).filter_cookies(cookies) }

    it { should eq filtered_cookies }
  end

  def assert_serializes(*keys)
    [File.open(__FILE__), Proc.new { puts "boo!" }, Module.new].each do |object|
      hash = {
        :strange_object => object,
        :sub_hash => {
          :sub_object => object
        },
        :array => [object]
      }

      payload_keys = keys.dup
      last_key = payload_keys.pop
      payload = described_class.new.sanitize(payload_keys.reverse.reduce({last_key => hash}) { |a,k| {k => a} })

      first_key = keys.shift
      hash = keys.reduce(payload[first_key]) {|a,k| a[k] }

      expect(hash[:strange_object]).to eq object.to_s # objects should be serialized
      expect(hash[:sub_hash]).to be_a Hash # subhashes should be kept
      expect(hash[:sub_hash][:sub_object]).to eq object.to_s # subhash members should be serialized
      expect(hash[:array]).to be_a Array # arrays should be kept
      expect(hash[:array].first).to eq object.to_s # array members should be serialized
    end
  end
end
