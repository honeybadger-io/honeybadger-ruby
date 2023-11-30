module Honeybadger
  class InvalidCheckinConfig < StandardError; end
  class CheckInSyncError < StandardError; end
  
  class CheckIn
    ATTRIBUTES = %w[name slug schedule_type report_period grace_period cron_schedule cron_timezone].freeze
    attr_reader :project_id, :data
    attr_accessor :deleted, :id

    def self.from_config(attrs)
      attrs = normalize_keys(attrs)
      self.new(attrs["project_id"], id: attrs["id"], attributes: attrs)
    end

    def self.from_remote(project_id, attrs)
      attrs = normalize_keys(attrs)
      self.new(project_id, id: attrs["id"], attributes: attrs)
    end

    def initialize(project_id, id: nil, attributes: nil)
      @project_id = project_id
      @id = id
      @data = attributes.slice(*ATTRIBUTES) if attributes.is_a?(Hash)
      @data["grace_period"] ||= ""
    end

    def ==(other)
      (data.reject {|k,v| v.nil?}) == (other.data.reject {|k,v| v.nil?})
    end


    def to_json
      output = {
        name: name,
        slug: slug || '',
        schedule_type: schedule_type,
        grace_period: grace_period || ''
      }
      if schedule_type == 'simple'
        output[:report_period] = report_period
      else
        output[:cron_schedule] = cron_schedule
        output[:cron_timezone] = cron_timezone || ""
      end

      output.to_json
    end

    ATTRIBUTES.each do |meth|
      define_method meth do
        data[meth]
      end
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
      @data = check_in.data
    end

    def deleted?
      @deleted
    end

    private 

    def blank?(str)
      str.nil? || str.to_s.strip == "" 
    end

    def self.normalize_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end