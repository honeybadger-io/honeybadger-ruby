module Honeybadger
  class InvalidCheckinConfig < StandardError; end
  class CheckInSyncError < StandardError; end
  
  class CheckIn
    attr_reader :project_id
    attr_accessor :name, :slug, :schedule_type, :report_period, :grace_period, :cron_schedule, :cron_timezone, :deleted, :id
    def self.from_config(config_entry)
      c = config_entry.transform_keys {|k| k.to_s }
      
      check_in = self.new(c["project_id"], c["id"])
      check_in.name = c["name"]
      check_in.slug = c["slug"]
      check_in.schedule_type = c["schedule_type"]
      check_in.report_period = c["report_period"]
      check_in.grace_period = c["grace_period"]
      check_in.cron_schedule = c["cron_schedule"]
      check_in.cron_timezone = c["cron_timezone"]
      check_in
    end
    
    def self.from_remote(project_id, data)
      check_in = self.new(project_id, data["id"])
      check_in.name = data["name"]
      check_in.slug = data["slug"]
      check_in.schedule_type = data["schedule_type"]
      check_in.report_period = data["report_period"]
      check_in.grace_period = data["grace_period"]
      check_in.cron_schedule = data["cron_schedule"]
      check_in.cron_timezone = data["cron_timezone"]
      check_in
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
      raise InvalidCheckinConfig.new('project_id is required for each check_in') if blank?(project_id)
      raise InvalidCheckinConfig.new('name is required for each check_in') if blank?(name)
      raise InvalidCheckinConfig.new("#{name} schedule_type must be either 'simple' or 'cron'") unless ['simple', 'cron'].include? schedule_type
      if schedule_type == 'simple'
        raise InvalidCheckinConfig.new("#{name} report_period is required for simple checkins") if blank?(report_period)
      else
        raise InvalidCheckinConfig.new("#{name} cron_schedule is required for cron checkins") if blank?(cron_schedule)
      end
    end

    def update_from(check_in)
      self.name = check_in.name
      self.slug = check_in.slug
      self.schedule_type = check_in.schedule_type
      self.report_period = check_in.report_period
      self.grace_period = check_in.grace_period
      self.cron_schedule = check_in.cron_schedule
      self.cron_timezone = check_in.cron_timezone
    end

    def deleted?
      @deleted
    end
  end
end