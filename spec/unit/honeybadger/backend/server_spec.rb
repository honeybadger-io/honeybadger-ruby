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
        get_one = stub_request(:get, "https://api.honeybadger.io/v2/projects/1234/check_ins/5678").to_return({
          status: 200,
          body: {
            name: "Test Checkin",
            slug: nil,
            schedule_type: "simple",
            report_period: "1 day",
            grace_period: "3 hours",
            cron_schedule: nil,
            cron_timezone: nil,
            id: "5678"
          }.to_json
        })
        checkin = subject.get_checkin("1234", "5678")
        expect(checkin).to be_a(Honeybadger::Checkin)
        expect(get_one).to have_been_made
      end

      it "should return nil if it gets a 404" do
        get_one = stub_request(:get, "https://api.honeybadger.io/v2/projects/1234/check_ins/5678").to_return({status: 404})
        checkin = subject.get_checkin("1234", "5678")
        expect(checkin).to be_nil
        expect(get_one).to have_been_made
      end
    end
    
    describe "#get_checkins" do
      it "should return an array of check ins" do
        get_all = stub_request(:get, "https://api.honeybadger.io/v2/projects/1234/check_ins").to_return({
          status: 200,
          body: {results: [{
            name: "Test Checkin",
            slug: nil,
            schedule_type: "simple",
            report_period: "1 day",
            grace_period: "3 hours",
            cron_schedule: nil,
            cron_timezone: nil,
            id: "5678"
          }]}.to_json
        })
        checkins = subject.get_checkins("1234")
        expect(checkins).to be_a(Array)
        expect(checkins.length).to eq(1)
        expect(checkins.first).to be_a(Honeybadger::Checkin)
        expect(get_all).to have_been_made
      end
    end

    describe "#create_checkin" do
      it "should return checkin" do
        post_one = stub_request(:post, "https://api.honeybadger.io/v2/projects/1234/check_ins").to_return({
          status: 200,
          body: {
            name: "Test Checkin",
            slug: nil,
            schedule_type: "simple",
            report_period: "1 day",
            grace_period: "3 hours",
            cron_schedule: nil,
            cron_timezone: nil,
            id: "5678"
          }.to_json
        })
        checkin = Honeybadger::Checkin.from_config({
          name: "Test Checkin",
          schedule_type: "simple",
          report_period: "1 day",
          grace_period: "3 hours"
        })
        result = subject.create_checkin("1234", checkin)
        expect(result).to be_a(Honeybadger::Checkin)
        expect(post_one).to have_been_made
      end
    end

    describe "#update_checkin" do
      it "should return checkin" do
        put_one = stub_request(:put, "https://api.honeybadger.io/v2/projects/1234/check_ins/5678").to_return({
          status: 200,
          body: {
            name: "Test Checkin",
            slug: nil,
            schedule_type: "simple",
            report_period: "2 days",
            grace_period: "3 hours",
            cron_schedule: nil,
            cron_timezone: nil,
            id: "5678"
          }.to_json
        })
        checkin = Honeybadger::Checkin.from_config({
          name: "Test Checkin",
          schedule_type: "simple",
          report_period: "2 days",
          grace_period: "3 hours"
        })
        result = subject.update_checkin("1234", "5678", checkin)
        expect(result).to be_a(Honeybadger::Checkin)
        expect(put_one).to have_been_made
      end
    end

    describe "#delete_checkin" do
      it "should accept a delete" do
        delete_one = stub_request(:delete, "https://api.honeybadger.io/v2/projects/1234/check_ins/5678").to_return(status: 200)
        result = subject.delete_checkin("1234", "5678")
        expect(result).to be_truthy
        expect(delete_one).to have_been_made
      end
    end
  end
end
