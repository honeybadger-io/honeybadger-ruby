require 'logger'
require 'honeybadger/backend/server'
require 'honeybadger/config'

describe Honeybadger::Backend::Server do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, api_key: 'abc123') }
  let(:logger) { config.logger }
  let(:payload) { double('Notice', to_json: '{}') }

  subject { described_class.new(config) }

  it { should respond_to :notify }
  it { should respond_to :check_in }

  describe "#check_in" do
    it "returns a response" do
      stub_http
      expect(subject.check_in('foobar')).to be_a Honeybadger::Backend::Response
    end
  end

  describe "#notify" do
    it "returns the response" do
      stub_http
      expect(notify_backend).to be_a Honeybadger::Backend::Response
    end

    context "when payload has an api key" do
      before do
        allow(payload).to receive(:api_key).and_return('badgers')
      end

      it "passes the payload api key in extra headers" do
        http = stub_http
        expect(http).to receive(:post).with(anything, anything, hash_including({ 'X-API-Key' => 'badgers'}))
        notify_backend
      end
    end

    context "when payload doesn't have an api key" do
      it "doesn't pass extra headers" do
        http = stub_http
        expect(http).to receive(:post).with(anything, anything, hash_including({ 'X-API-Key' => 'abc123'}))
        notify_backend
      end
    end

    context "when encountering exceptions" do
      context "HTTP connection setup problems" do
        it "should not be rescued" do
          proxy = double()
          allow(proxy).to receive(:new).and_raise(NoMemoryError)
          allow(Net::HTTP).to receive(:Proxy).and_return(proxy)
          expect { notify_backend }.to raise_error(NoMemoryError)
        end
      end

      context "connection errors" do
        it "returns Response" do
          http = stub_http
          Honeybadger::Backend::Server::HTTP_ERRORS.each do |error|
            allow(http).to receive(:post).and_raise(error)
            result = notify_backend
            expect(result).to be_a Honeybadger::Backend::Response
            expect(result.code).to eq :error
          end
        end

        it "doesn't fail when posting an http exception occurs" do
          http = stub_http
          Honeybadger::Backend::Server::HTTP_ERRORS.each do |error|
            allow(http).to receive(:post).and_raise(error)
            expect { notify_backend }.not_to raise_error
          end
        end
      end
    end

    
    def notify_backend
      subject.notify(:notices, payload)
    end
    
  end
  
  describe "sync checkins API" do
    describe "#get_checkin" do
      it "should get one check in" do
        get_one = stub_request(:get, "https://app.honeybadger.io/v2/projects/1234/check_ins/5678").to_return({
          status: 200,
          body: {
            name: "Test CheckIn",
            slug: nil,
            schedule_type: "simple",
            report_period: "1 day",
            grace_period: "3 hours",
            cron_schedule: nil,
            cron_timezone: nil,
            id: "5678"
          }.to_json
        })
        check_in = subject.get_check_in("1234", "5678")
        expect(check_in).to be_a(Honeybadger::CheckIn)
        expect(get_one).to have_been_made
      end

      it "should return nil if it gets a 404" do
        get_one = stub_request(:get, "https://app.honeybadger.io/v2/projects/1234/check_ins/5678").to_return({status: 404})
        check_in = subject.get_check_in("1234", "5678")
        expect(check_in).to be_nil
        expect(get_one).to have_been_made
      end
    end

    describe "#get_checkins" do
      it "should return an array of check ins" do
        get_all = stub_request(:get, "https://app.honeybadger.io/v2/projects/1234/check_ins").to_return({
          status: 200,
          body: {results: [{
            name: "Test CheckIn",
            slug: nil,
            schedule_type: "simple",
            report_period: "1 day",
            grace_period: "3 hours",
            cron_schedule: nil,
            cron_timezone: nil,
            id: "5678"
          }]}.to_json
        })
        checkins = subject.get_check_ins("1234")
        expect(checkins).to be_a(Array)
        expect(checkins.length).to eq(1)
        expect(checkins.first).to be_a(Honeybadger::CheckIn)
        expect(get_all).to have_been_made
      end
    end

    describe "#create_check_in" do
      it "should return check_in" do
        post_one = stub_request(:post, "https://app.honeybadger.io/v2/projects/1234/check_ins").to_return({
          status: 200,
          body: {
            name: "Test CheckIn",
            slug: nil,
            schedule_type: "simple",
            report_period: "1 day",
            grace_period: "3 hours",
            cron_schedule: nil,
            cron_timezone: nil,
            id: "5678"
          }.to_json
        })
        check_in = Honeybadger::CheckIn.from_config({
          name: "Test CheckIn",
          schedule_type: "simple",
          report_period: "1 day",
          grace_period: "3 hours"
        })
        result = subject.create_check_in("1234", check_in)
        expect(result).to be_a(Honeybadger::CheckIn)
        expect(post_one).to have_been_made
      end
    end

    describe "#update_check_in" do
      it "should return check_in" do
        put_one = stub_request(:put, "https://app.honeybadger.io/v2/projects/1234/check_ins/5678").to_return({
          status: 200,
          body: {
            name: "Test CheckIn",
            slug: nil,
            schedule_type: "simple",
            report_period: "2 days",
            grace_period: "3 hours",
            cron_schedule: nil,
            cron_timezone: nil,
            id: "5678"
          }.to_json
        })
        check_in = Honeybadger::CheckIn.from_config({
          name: "Test CheckIn",
          schedule_type: "simple",
          report_period: "2 days",
          grace_period: "3 hours"
        })
        result = subject.update_check_in("1234", "5678", check_in)
        expect(result).to be_a(Honeybadger::CheckIn)
        expect(put_one).to have_been_made
      end
    end

    describe "#delete_check_in" do
      it "should accept a delete" do
        delete_one = stub_request(:delete, "https://app.honeybadger.io/v2/projects/1234/check_ins/5678").to_return(status: 200)
        result = subject.delete_check_in("1234", "5678")
        expect(result).to be_truthy
        expect(delete_one).to have_been_made
      end
    end
  end
end
