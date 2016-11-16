require 'honeybadger/rack/request_hash'

describe Honeybadger::Rack::RequestHash, if: defined?(Rack) do
  let(:rack_env) { Rack::MockRequest.env_for('/') }

  subject { described_class.from_env(rack_env) }

  describe "cgi_data" do
    it "includes UPPER_CASE_KEY" do
      rack_env['UPPER_CASE_KEY'] = 'foo'
      expect(subject[:cgi_data]['UPPER_CASE_KEY']).to eq 'foo'
    end

    it "excludes RAW_POST_DATA" do
      rack_env['RAW_POST_DATA'] = 'foo'
      expect(subject[:cgi_data]).not_to have_key 'RAW_POST_DATA'
    end

    it "excludes QUERY_STRING" do
      rack_env['QUERY_STRING'] = 'foo'
      expect(subject[:cgi_data]).not_to have_key 'QUERY_STRING'
    end
  end
end
