require 'honeybadger/backend/test'
require 'honeybadger/config'
require 'honeybadger/check_in'


describe Honeybadger::Backend::Test do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER) }
  let(:logger) { config.logger }

  let(:instance) { described_class.new(config) }

  subject { instance }

  before do
    Honeybadger::Backend::Test.notifications.clear
    Honeybadger::Backend::Test.check_ins.clear
  end

  it { should respond_to :notifications }

  describe "#notifications" do
    it "sets a default key value rather than just return one" do
      expect(instance.notifications).not_to have_key(:foo)
      expect(instance.notifications[:foo]).to eq []
      expect(instance.notifications).to have_key(:foo)
    end
  end

  describe "#notify" do
  let(:notice) { double('Notice') }

  subject { instance.notify(:notices, double('Notice')) }

    it "saves notifications for review" do
      expect { instance.notify(:notices, notice) }.to change { instance.notifications[:notices] }.from([]).to([notice])
    end

    it { should be_a Honeybadger::Backend::Response }
  end

  describe "#check_in" do
  it "saves check_in for review" do
    expect { instance.check_in(10) }.to change { instance.check_ins }.from([]).to([10])
  end

    it "should return a Honeybadger::Backend::Response" do
      expect(instance.check_in(10)).to be_a Honeybadger::Backend::Response
    end
  end

  context "check_in sync crud methods" do
    before do
      Honeybadger::Backend::Test.check_in_configs.clear
    end

    describe "#set_check_in" do
      it "should set object on class" do
        check_in = Honeybadger::CheckIn.from_config({
          project_id: "1234",
          name: "Test check_in",
          schedule_type: "simple",
          report_period: "1 hour"
        })

        subject.set_check_in("1234", "5678", check_in)
        expect(subject.check_in_configs["1234"]["5678"]).to eq(check_in)
      end
    end

    describe "#get_checkin" do
      it "should return nil if check_in does not exist" do
        expect(subject.get_check_in("1234", "5678")).to be_nil
      end
      it "should return check_in if it exists" do
        check_in = Honeybadger::CheckIn.from_config({
          project_id: "1234",
          name: "Test check_in",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        subject.set_check_in("1234", "5678", check_in)
        expect(subject.get_check_in("1234", "5678")).to eq(check_in)
      end
    end

    describe "#get_checkins" do
      it "should return empty array if no check_in exists" do
        expect(subject.get_check_ins("1234")).to be_empty
      end
      it "should return array if check_in exists" do
        check_in = Honeybadger::CheckIn.from_config({
          project_id: "1234",
          name: "Test check_in",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        subject.set_check_in("1234", "5678", check_in)
        expect(subject.get_check_ins("1234").first).to eq(check_in)
      end
    end

    describe "#create_check_in" do
      it "should create check_in and return it" do
        check_in = Honeybadger::CheckIn.from_config({
          project_id: "1234",
          name: "Test check_in",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        created = subject.create_check_in("1234", check_in)
        expect(created.id).to_not be_nil
        expect(subject.check_in_configs["1234"][created.id]).to_not be_nil
      end
    end

    describe "#update_check_in" do
      it "should update check_in and return it" do
        check_in = Honeybadger::CheckIn.from_config({
          project_id: "1234",
          name: "Test check_in",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        checkin_update = Honeybadger::CheckIn.from_config({
          project_id: "1234",
          name: "Test check_in",
          schedule_type: "simple",
          report_period: "2 hours"
        })

        subject.set_check_in("1234", "5678", check_in)
        updated = subject.update_check_in("1234", "5678", checkin_update)

        expect(updated.report_period).to eq("2 hours")
        expect(subject.check_in_configs["1234"]["5678"].report_period).to eq("2 hours")
      end
    end

    describe "#delete_check_in" do
      it "should update check_in and return it" do
        check_in = Honeybadger::CheckIn.from_config({
          project_id: "1234",
          name: "Test check_in",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        subject.set_check_in("1234", "5678", check_in)
        expect(subject.check_in_configs["1234"]["5678"]).to_not be_nil

        expect(subject.delete_check_in("1234", "5678")).to be_truthy
        expect(subject.check_in_configs["1234"]["5678"]).to be_nil
      end
    end
  end
end
