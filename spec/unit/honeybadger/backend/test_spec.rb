require 'honeybadger/backend/test'
require 'honeybadger/config'
require 'honeybadger/checkin'


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

  context "checkin sync crud methods" do
    before do
      Honeybadger::Backend::Test.checkin_configs.clear
    end

    describe "#set_checkin" do
      it "should set object on class" do
        checkin = Honeybadger::Checkin.from_config({
          project_id: "1234",
          name: "Test checkin",
          schedule_type: "simple",
          report_period: "1 hour"
        })

        subject.set_checkin("1234", "5678", checkin)
        expect(subject.checkin_configs["1234"]["5678"]).to eq(checkin)
      end
    end

    describe "#get_checkin" do
      it "should return nil if checkin does not exist" do
        expect(subject.get_checkin("1234", "5678")).to be_nil
      end
      it "should return checkin if it exists" do
        checkin = Honeybadger::Checkin.from_config({
          project_id: "1234",
          name: "Test checkin",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        subject.set_checkin("1234", "5678", checkin)
        expect(subject.get_checkin("1234", "5678")).to eq(checkin)
      end
    end

    describe "#get_checkins" do
      it "should return empty array if no checkin exists" do
        expect(subject.get_checkins("1234")).to be_empty
      end
      it "should return array if checkin exists" do
        checkin = Honeybadger::Checkin.from_config({
          project_id: "1234",
          name: "Test checkin",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        subject.set_checkin("1234", "5678", checkin)
        expect(subject.get_checkins("1234").first).to eq(checkin)
      end
    end

    describe "#create_checkin" do
      it "should create checkin and return it" do
        checkin = Honeybadger::Checkin.from_config({
          project_id: "1234",
          name: "Test checkin",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        created = subject.create_checkin("1234", checkin)
        expect(created.id).to_not be_nil
        expect(subject.checkin_configs["1234"][created.id]).to_not be_nil
      end
    end

    describe "#update_checkin" do
      it "should update checkin and return it" do
        checkin = Honeybadger::Checkin.from_config({
          project_id: "1234",
          name: "Test checkin",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        checkin_update = Honeybadger::Checkin.from_config({
          project_id: "1234",
          name: "Test checkin",
          schedule_type: "simple",
          report_period: "2 hours"
        })

        subject.set_checkin("1234", "5678", checkin)
        updated = subject.update_checkin("1234", "5678", checkin_update)

        expect(updated.report_period).to eq("2 hours")
        expect(subject.checkin_configs["1234"]["5678"].report_period).to eq("2 hours")
      end
    end

    describe "#delete_checkin" do
      it "should update checkin and return it" do
        checkin = Honeybadger::Checkin.from_config({
          project_id: "1234",
          name: "Test checkin",
          schedule_type: "simple",
          report_period: "1 hour"
        })
        subject.set_checkin("1234", "5678", checkin)
        expect(subject.checkin_configs["1234"]["5678"]).to_not be_nil

        expect(subject.delete_checkin("1234", "5678")).to be_truthy
        expect(subject.checkin_configs["1234"]["5678"]).to be_nil
      end
    end
  end
end
