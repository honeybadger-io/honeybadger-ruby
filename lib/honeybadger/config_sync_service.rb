require 'honeybadger/check_in'
module Honeybadger
  class ConfigSyncService
    def initialize(config)
      @config = config
      @check_ins_cache = nil
    end

    def sync_checkins
      checkin_configs = @config.get(:checkins) || []
      return [] if checkin_configs.empty?

      checkins = checkin_configs.map do |cfg|
        check_in = CheckIn.from_config(cfg)
        check_in.validate!
        check_in
      end

      check_unique_names(checkins)

      created_or_updated = sync_existing_checkins(checkins)
      removed = sync_removed_checkins(checkins)

      return created_or_updated + removed
    end

    private

    def check_unique_names(checkins)
      names = checkins.map(&:name)
      dupes = names.find_all {|n| names.count(n) > 1}.uniq
      raise Honeybadger::InvalidCheckinConfig.new("Check Ins need to have unique names. #{dupes.join(", ")} used multiple times.") if dupes.length > 0
    end

    def get_checkin_by_name(project_id, name)
      @check_ins_cache ||= @config.backend.get_check_ins(project_id)
      @check_ins_cache.find {|c| c.name == name }
    end

    def sync_existing_checkins(checkins = [])
      return [] if checkins.empty?
      result = []
      checkins.each do |check_in|
        remote_checkin = if check_in.id
          @config.backend.get_check_in(check_in.project_id, check_in.id)
        else
          get_checkin_by_name(check_in.project_id, check_in.name)
        end
        if remote_checkin
          unless remote_checkin == check_in
            result << @config.backend.update_check_in(check_in.project_id, remote_checkin.id, check_in)
          end
        else
          result << @config.backend.create_check_in(check_in.project_id, check_in)
        end
      end
      result
    end

    def sync_removed_checkins(checkins)
      return [] if checkins.nil? || checkins.empty?
      result = []
      project_ids = checkins.map{|ch| ch.project_id }.uniq
      project_ids.each do |prj_id|
        @check_ins_cache ||= @config.backend.get_check_ins(prj_id)

        local_project_checkins = checkins.select {|c| c.project_id == prj_id }
        to_remove = @check_ins_cache.reject do |pc|
          local_project_checkins.find{|c| c.id == pc.id || c.name == pc.name }
        end
        to_remove.each do |ch|
          @config.backend.delete_check_in(prj_id, ch.id)
          ch.deleted = true
          result << ch
        end
      end
      result
    end
  end
end
