require "honeybadger/util/request_hash"

describe Honeybadger::Util::RequestHash, if: defined?(Rack) do
  let(:rack_env) { Rack::MockRequest.env_for("/") }

  subject { described_class.from_env(rack_env) }

  describe "cgi_data" do
    it "includes all HTTP headers" do
      rack_env["HTTP_SOME_RANDOM_HEADER"] = "foo"
      expect(subject[:cgi_data]["HTTP_SOME_RANDOM_HEADER"]).to eq "foo"
    end

    it "includes approved CGI variables" do
      rack_env["REMOTE_ADDR"] = "127.0.0.1"
      expect(subject[:cgi_data]["REMOTE_ADDR"]).to eq "127.0.0.1"
    end

    it "excludes RAW_POST_DATA" do
      rack_env["RAW_POST_DATA"] = "foo"
      expect(subject[:cgi_data]).not_to have_key "RAW_POST_DATA"
    end

    it "excludes QUERY_STRING" do
      rack_env["QUERY_STRING"] = "foo"
      expect(subject[:cgi_data]).not_to have_key "QUERY_STRING"
    end

    it "excludes symbols" do
      rack_env[:foo] = "foo"
      expect(subject[:cgi_data]).not_to have_key :foo
    end
  end
end
