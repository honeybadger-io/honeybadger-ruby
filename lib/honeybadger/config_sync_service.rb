require 'honeybadger/checkin'
module Honeybadger
  class ConfigSyncService
    def initialize(config)
      @config = config
    end

    def sync_checkins
      checkin_configs = @config.get(:checkins) || []
      return [] if checkin_configs.empty?

      checkins = checkin_configs.map do |cfg|
        checkin = Checkin.from_config(cfg)
        checkin.validate!
        checkin
      end
      created_or_updated = sync_existing_checkins(checkins)
      removed = sync_removed_checkins(checkins)

      return (created_or_updated + removed).uniq
    end

    private

    def get_checkin_by_name(project_id, name)
      checkins = @config.backend.get_checkins(project_id)
      checkins.find {|c| c.name == name }
    end

    def sync_existing_checkins(checkins = [])
      return [] if checkins.empty?
      result = []
      checkins.each do |checkin|
        remote_checkin = if checkin.id
          @config.backend.get_checkin(checkin.project_id, checkin.id)
        else
          get_checkin_by_name(checkin.project_id, checkin.name)
        end
        if remote_checkin
          unless remote_checkin == checkin
            result << @config.backend.update_checkin(checkin.project_id, remote_checkin.id, checkin)
          end
        else
          result << @config.backend.create_checkin(checkin.project_id, checkin)
        end
      end
      result
    end

    def sync_removed_checkins(checkins)
      return [] if checkins.nil? || checkins.empty?
      result = []
      project_ids = checkins.map{|ch| ch.project_id }.uniq
      project_ids.each do |prj_id|
        project_checkins = @config.backend.get_checkins(prj_id)

        local_project_checkins = checkins.select {|c| c.project_id == prj_id }
        to_remove = project_checkins.reject do |pc| 
          local_project_checkins.find{|c| c.id == pc.id || c.name == pc.name }
        end
        to_remove.each do |ch|
          if ch.id.nil?
            ch = get_checkin_by_name(prj_id, ch.name)
          end
          @config.backend.delete_checkin(prj_id, ch.id)
          ch.deleted = true
          result << ch
        end
      end
      result
    end
  end
end