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
    let(:expected_hash) { {}.tap {|h| max_depth.times.each {|i| h = h[i.to_s] = (i < max_depth-1 ? {:string => 'string'} : '[max depth reached]') }} }
    let(:sanitized_hash) { described_class.new(deep_hash, :max_depth => max_depth) }
    let(:max_depth) { 10 }

    it "truncates nested hashes to max_depth" do
      expect(sanitized_hash['0']).to eq(expected_hash['0'])
    end

    it "does not allow infinite recursion" do
      hash = {:a => :a}
      hash[:hash] = hash
      payload = described_class.new(:request => {:params => hash})
      expect(payload.request[:params][:hash]).to eq "[possible infinite recursion halted]"
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
  end

  it "filters parameters" do
    assert_filters_request(:params)
  end

  it "filters cgi data" do
    assert_filters_request(:cgi_data)
  end

  it "filters session" do
    assert_filters_request(:session)
  end

  it "filters local_variables" do
    assert_filters_request(:local_variables)
  end

  context 'filtered parameters in query string' do
    let(:params_filters) { [:foo, :bar] }

    describe '#url' do
      subject { described_class.new({:request => {:url => 'https://www.honeybadger.io/?foo=1&bar=2&baz=3'}}, :filters => params_filters).request[:url] }

      it 'filters query' do
        expect(subject).to eq 'https://www.honeybadger.io/?foo=[FILTERED]&bar=[FILTERED]&baz=3'
      end
    end

    describe '#cgi_data' do
      let(:cgi_data) { { 'QUERY_STRING' => 'foo=1&bar=2&baz=3', 'ORIGINAL_FULLPATH' => '/?foo=1&bar=2&baz=3' } }

      subject { described_class.new({:request => {:cgi_data => cgi_data}}, :filters => params_filters).request[:cgi_data] }

      it 'filters QUERY_STRING key' do
        expect(subject['QUERY_STRING']).to eq 'foo=[FILTERED]&bar=[FILTERED]&baz=3'
      end

      it 'filters ORIGINAL_FULLPATH key' do
        expect(subject['ORIGINAL_FULLPATH']).to eq '/?foo=[FILTERED]&bar=[FILTERED]&baz=3'
      end
    end
  end

  describe '#filter_url!' do
    subject { described_class.new.send(:filter_url!, url) }

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
      before { expect { URI.parse(url) }.to raise_error }
      it { should eq url }
    end

    context 'complex url' do
      let(:url) { 'https://foo:bar@www.honeybadger.io:123/asdf/?foo=1&bar=2&baz=3' }
      it { should eq url }
    end
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
      payload = described_class.new(payload_keys.reverse.reduce({last_key => hash}) { |a,k| {k => a} })

      first_key = keys.shift
      hash = keys.reduce(payload[first_key]) {|a,k| a[k] }

      expect(hash[:strange_object]).to eq object.to_s # objects should be serialized
      expect(hash[:sub_hash]).to be_a Hash # subhashes should be kept
      expect(hash[:sub_hash][:sub_object]).to eq object.to_s # subhash members should be serialized
      expect(hash[:array]).to be_a Array # arrays should be kept
      expect(hash[:array].first).to eq object.to_s # array members should be serialized
    end
  end

  def assert_filters_request(attribute)
    filters  = ["abc", :def, /private/, /^foo_.*$/]
    original = { 'abc' => "123", 'def' => "456", 'ghi' => "789", 'nested' => { 'abc' => '100' },
      'something_with_abc' => 'match the entire string', 'private_param' => 'prra',
      'foo_param' => 'bar', 'not_foo_param' => 'baz', 'nested_foo' => { 'foo_nested' => 'bla'} }
    filtered = { 'abc'    => "[FILTERED]",
                 'def'    => "[FILTERED]",
                 'something_with_abc' => "match the entire string",
                 'ghi'    => "789",
                 'nested' => { 'abc' => '[FILTERED]' },
                 'private_param' => '[FILTERED]',
                 'foo_param' => '[FILTERED]',
                 'not_foo_param' => 'baz',
                 'nested_foo' => { 'foo_nested' => '[FILTERED]'}
    }

    payload = described_class.new({:request => {attribute => original}}, {:filters => filters})

    expect(payload.request[attribute]).to eq filtered
  end
end
