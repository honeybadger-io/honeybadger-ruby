require 'logger'
require 'honeybadger/backend/server'
require 'honeybadger/config'
require 'honeybadger/config_sync_service'
require 'honeybadger/check_in'

describe Honeybadger::ConfigSyncService do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, api_key: 'abc123', backend: 'test') }
  let(:logger) { config.logger }

  subject { described_class.new(config) }

  context "sync check_in configs" do

    before {
      config.backend.check_in_configs.clear
    }

    it "syncs with empty array" do
      config.set(:check_ins, [])
      result = subject.sync_check_ins
      expect(result).to be_empty
    end

    it "syncs with good check_in by id, unchanged" do
      config.set(:check_ins, [{project_id: '1234', id: '5678', name: 'Main Web App CheckIn', schedule_type: 'simple', report_period: '1 hour'}])
      config.backend.set_check_in("1234", "5678", Honeybadger::CheckIn.from_config({
        project_id: "1234",
        id: "5678",
        name: "Main Web App CheckIn", schedule_type: "simple", report_period: "1 hour",
      }))
      result = subject.sync_check_ins
      expect(result).to be_empty
    end

    it "syncs with good check_in by name, unchanged" do
      config.set(:check_ins, [{project_id: '1234', name: 'Main Web App CheckIn', schedule_type: 'simple', report_period: '1 hour'}])
      config.backend.set_check_in("1234", "5678", Honeybadger::CheckIn.from_config({
        project_id: "1234",
        id: "5678",
        name: "Main Web App CheckIn", slug: nil, schedule_type: "simple", report_period: "1 hour",
      }))
      result = subject.sync_check_ins
      expect(result).to be_empty
    end

    it "syncs with good check_in by id, with changes" do
      config.set(:check_ins, [{project_id: '1234', id: '5678', name: 'Main Web App CheckIn', schedule_type: 'simple', report_period: '2 hours'}])
      config.backend.set_check_in("1234", "5678", Honeybadger::CheckIn.from_config({
        project_id: "1234",
        id: "5678",
        name: "Main Web App CheckIn", slug: nil, schedule_type: "simple", report_period: "1 hour",
      }))
      result = subject.sync_check_ins

      expect(result.length).to eq(1)
      expect(result.first.id).to eq("5678")
    end

    it "syncs with new check_in" do
      new_project = {project_id: '1234', name: 'Main Web App CheckIn', schedule_type: 'simple', report_period: '1 hour'}
      config.set(:check_ins, [new_project])

      result = subject.sync_check_ins

      expect(result.length).to eq(1)
      expect(result.first.id).to eq("1")
    end

    it "syncs with removed check_ins" do
      config.set(:check_ins, [{project_id: '1234', id: "5678", name: 'Main Web App CheckIn', schedule_type: 'simple', report_period: '1 hour'}])
      config.backend.set_check_in("1234", "5678", Honeybadger::CheckIn.from_config({
        project_id: "1234",
        id: "5678",
        name: "Main Web App CheckIn", slug: nil, schedule_type: "simple", report_period: "1 hour",
      }))
      config.backend.set_check_in("1234", "dele", Honeybadger::CheckIn.from_config({
        project_id: "1234",
        id: "dele",
        name: "to be deleted", slug: nil, schedule_type: "simple", report_period: "1 hour",
      }))

      result = subject.sync_check_ins

      expect(result.length).to eq(1)
      expect(result.first.deleted?).to be_truthy
    end

    it "does not sync with invalid array" do
      config.set(:check_ins, [{ project_id: '1234' }])
      expect { subject.sync_check_ins }.to raise_error Honeybadger::InvalidCheckinConfig
    end

    it "does not sync with multiple sampe names" do
      check_in_configs = [
        { project_id: '1234', name: 'a', schedule_type: 'simple', report_period: '1 hour' },
        { project_id: '1234', name: 'a', schedule_type: 'simple', report_period: '2 hours' }
      ]
      config.set(:check_ins, check_in_configs)
      expect { subject.sync_check_ins }.to raise_error(Honeybadger::InvalidCheckinConfig, /need to have unique names/)
    end
  end
end
