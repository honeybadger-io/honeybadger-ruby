require 'honeybadger/backend/null'

module Honeybadger
  module Backend
    class Test < Null
      # The notification list.
      #
      # @example
      #   Test.notifications[:notices] # => [Notice, Notice, ...]
      #
      # @return [Hash] Notifications hash.
      def self.notifications
        @notifications ||= Hash.new {|h,k| h[k] = [] }
      end

      # @api public
      # The check in list.
      #
      # @example
      #   Test.check_ins # => ["foobar", "danny", ...]
      #
      # @return [Array<Object>] List of check ins.
      def self.check_ins
        @check_ins ||= []
      end

      def notifications
        self.class.notifications
      end

      def check_ins
        self.class.check_ins
      end

      def notify(feature, payload)
        notifications[feature] << payload
        super
      end

      def check_in(id)
        check_ins << id
        super
      end
      
      # only for use within tests
      def set_checkin(project_id, id, data)
        @checkin_configs ||= {}
        @checkin_configs[project_id] = @checkin_configs[project_id] || {} 
        @checkin_configs[project_id][id] = data
      end
      
      def get_checkin(project_id, id)
        @checkin_configs ||= {}
        @checkin_configs[project_id]&.[](id)
      end
      
      def get_checkins(project_id)
        @checkin_configs ||= {}
        @checkin_configs[project_id] = @checkin_configs[project_id] || {} 
        return [] if @checkin_configs[project_id].empty?
        @checkin_configs[project_id].values
      end
      
      def create_checkin(project_id, data)
        @checkin_configs ||= {}
        @checkin_configs[project_id] = @checkin_configs[project_id] || {}
        id = @checkin_configs[project_id].length + 1
        loop do
          break unless @checkin_configs[project_id].has_key?(id)
          id += 1  
        end
        id = id.to_s
        data.id = id
        @checkin_configs[project_id][id] = data
      end

      def update_checkin(project_id, id, data)
        @checkin_configs ||= {}
        if @checkin_configs[project_id]&.[](id)
          @checkin_configs[project_id][id] = data
          return data
        else
          raise "Update failed"
        end
      end
      
      def delete_checkin(project_id, id)
        @checkin_configs ||= {}
        if @checkin_configs[project_id]&.[](id)
          @checkin_configs[project_id].delete(id)
        else
          raise "Delete failed"
        end
      end
    end
  end
end
