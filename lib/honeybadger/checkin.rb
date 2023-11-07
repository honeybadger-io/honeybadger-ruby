module Honeybadger
  class InvalidCheckinConfig < StandardError; end
  class CheckinSyncError < StandardError; end
  
  class Checkin
    attr_reader :project_id
    attr_accessor :name, :slug, :schedule_type, :report_period, :grace_period, :cron_schedule, :cron_timezone, :deleted, :id
    def self.from_config(config_entry)
      c = config_entry.transform_keys {|k| k.to_s }
      
      checkin = self.new(c["project_id"], c["id"])
      checkin.name = c["name"]
      checkin.slug = c["slug"]
      checkin.schedule_type = c["schedule_type"]
      checkin.report_period = c["report_period"]
      checkin.grace_period = c["grace_period"]
      checkin.cron_schedule = c["cron_schedule"]
      checkin.cron_timezone = c["cron_timezone"]
      checkin
    end
    
    def self.from_remote(project_id, data)
      checkin = self.new(project_id, data["id"])
      checkin.name = data["name"]
      checkin.slug = data["slug"]
      checkin.schedule_type = data["schedule_type"]
      checkin.report_period = data["report_period"]
      checkin.grace_period = data["grace_period"]
      checkin.cron_schedule = data["cron_schedule"]
      checkin.cron_timezone = data["cron_timezone"]
      checkin
    end

    def initialize(project_id, id = nil)
      @project_id = project_id
      @id = id
      @deleted = false
    end

    def ==(other)
      self.name == other.name &&
      self.slug == other.slug &&
      self.schedule_type == other.schedule_type &&
      self.report_period == other.report_period &&
      self.grace_period == other.grace_period &&
      self.cron_schedule == other.cron_schedule &&
      self.cron_timezone == other.cron_timezone
    end

    def to_json
      {
        name: name, slug: slug, schedule_type: schedule_type, 
        report_period: report_period, grace_period: grace_period, 
        cron_schedule: cron_schedule, cron_timezone: cron_timezone
      }.to_json
    end

    def blank?(str)
      str.nil? || str == "" 
    end

    def validate!
      raise InvalidCheckinConfig.new('project_id is required for each checkin') if blank?(project_id)
      raise InvalidCheckinConfig.new('name is required for each checkin') if blank?(name)
      raise InvalidCheckinConfig.new("#{name} schedule_type must be either 'simple' or 'cron'") unless ['simple', 'cron'].include? schedule_type
      if schedule_type == 'simple'
        raise InvalidCheckinConfig.new("#{name} report_period is required for simple checkins") if blank?(report_period)
      else
        raise InvalidCheckinConfig.new("#{name} cron_schedule is required for cron checkins") if blank?(cron_schedule)
      end
    end

    def update_from(checkin)
      self.name = checkin.name
      self.slug = checkin.slug
      self.schedule_type = checkin.schedule_type
      self.report_period = checkin.report_period
      self.grace_period = checkin.grace_period
      self.cron_schedule = checkin.cron_schedule
      self.cron_timezone = checkin.cron_timezone
    end

    def deleted?
      @deleted
    end
  end
end