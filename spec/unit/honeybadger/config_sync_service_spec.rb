require 'logger'
require 'honeybadger/backend/server'
require 'honeybadger/config'
require 'honeybadger/config_sync_service'
require 'honeybadger/checkin'

describe Honeybadger::ConfigSyncService do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, api_key: 'abc123', backend: 'test') }
  let(:logger) { config.logger }

  subject { described_class.new(config) }

  context "sync checkin configs" do

    before {
      config.backend.checkin_configs.clear
    }

    it "syncs with empty array" do
      config.set(:checkins, [])
      result = subject.sync_checkins
      expect(result).to be_empty
    end

    it "syncs with good checkin by id, unchanged" do
      config.set(:checkins, [{project_id: '1234', id: '5678', name: 'Main Web App Checkin', schedule_type: 'simple', report_period: '1 hour'}])
      config.backend.set_checkin("1234", "5678", Honeybadger::Checkin.from_config({
        project_id: "1234",
        id: "5678",
        name: "Main Web App Checkin", schedule_type: "simple", report_period: "1 hour",
      }))
      result = subject.sync_checkins
      expect(result).to be_empty
    end

    it "syncs with good checkin by name, unchanged" do
      config.set(:checkins, [{project_id: '1234', name: 'Main Web App Checkin', schedule_type: 'simple', report_period: '1 hour'}])
      config.backend.set_checkin("1234", "5678", Honeybadger::Checkin.from_config({
        project_id: "1234",
        id: "5678",
        name: "Main Web App Checkin", slug: nil, schedule_type: "simple", report_period: "1 hour",
      }))
      result = subject.sync_checkins
      expect(result).to be_empty
    end

    it "syncs with good checkin by id, with changes" do
      config.set(:checkins, [{project_id: '1234', id: '5678', name: 'Main Web App Checkin', schedule_type: 'simple', report_period: '2 hours'}])
      config.backend.set_checkin("1234", "5678", Honeybadger::Checkin.from_config({
        project_id: "1234",
        id: "5678",
        name: "Main Web App Checkin", slug: nil, schedule_type: "simple", report_period: "1 hour",
      }))
      result = subject.sync_checkins

      expect(result.length).to eq(1)
      expect(result.first.id).to eq("5678")
    end

    it "syncs with new checkin" do
      new_project = {project_id: '1234', name: 'Main Web App Checkin', schedule_type: 'simple', report_period: '1 hour'}
      config.set(:checkins, [new_project])

      result = subject.sync_checkins

      expect(result.length).to eq(1)
      expect(result.first.id).to eq("1")
    end

    it "syncs with removed checkins" do
      config.set(:checkins, [{project_id: '1234', id: "5678", name: 'Main Web App Checkin', schedule_type: 'simple', report_period: '1 hour'}])
      config.backend.set_checkin("1234", "5678", Honeybadger::Checkin.from_config({
        project_id: "1234",
        id: "5678",
        name: "Main Web App Checkin", slug: nil, schedule_type: "simple", report_period: "1 hour",
      }))
      config.backend.set_checkin("1234", "dele", Honeybadger::Checkin.from_config({
        project_id: "1234",
        id: "dele",
        name: "to be deleted", slug: nil, schedule_type: "simple", report_period: "1 hour",
      }))

      result = subject.sync_checkins

      expect(result.length).to eq(1)
      expect(result.first.deleted?).to be_truthy
    end

    it "does not sync with invalid array" do
      config.set(:checkins, [{ project_id: '1234' }])
      expect { subject.sync_checkins }.to raise_error Honeybadger::InvalidCheckinConfig
    end
  end
end
