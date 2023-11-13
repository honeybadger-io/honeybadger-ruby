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

      def self.checkin_configs
        @checkin_configs ||= {}
      end

      def checkin_configs
        self.class.checkin_configs
      end

      # Set checkin by id, only for use in tests
      # @example
      #   backend.set_checkin('1234', 'ajdja', checkin)
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @param [Checkin] data Checkin object with config
      def set_checkin(project_id, id, data)
        self.checkin_configs[project_id] = self.checkin_configs[project_id] || {}
        self.checkin_configs[project_id][id] = data
      end

      # Get checkin by id
      # @example
      #   backend.get_checkin('1234', 'ajdja")
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @returns [Checkin] or nil if checkin is not found
      def get_checkin(project_id, id)
        self.checkin_configs ||= {}
        self.checkin_configs[project_id]&.[](id)
      end

      # Get checkins by project
      # @example
      #   backend.get_checkins('1234')
      #
      # @param [String] project_id The unique project id
      # @returns [Array<Checkin>] All checkins for this project
      def get_checkins(project_id)
        self.checkin_configs ||= {}
        self.checkin_configs[project_id] = self.checkin_configs[project_id] || {}
        return [] if self.checkin_configs[project_id].empty?
        self.checkin_configs[project_id].values
      end

      # Create checkin on project
      # @example
      #   backend.create_checkin('1234', checkin)
      #
      # @param [String] project_id The unique project id
      # @param [Checkin] data A Checkin object encapsulating the config
      # @returns [Checkin] A checkin object containing the id
      def create_checkin(project_id, data)
        self.checkin_configs ||= {}
        self.checkin_configs[project_id] = self.checkin_configs[project_id] || {}
        id = self.checkin_configs[project_id].length + 1
        loop do
          break unless self.checkin_configs[project_id].has_key?(id)
          id += 1
        end
        id = id.to_s
        data.id = id
        self.checkin_configs[project_id][id] = data
        data
      end

      # Update checkin on project
      # @example
      #   backend.update_checkin('1234', 'eajaj', checkin)
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @param [Checkin] data A Checkin object encapsulating the config
      # @returns [Checkin] updated Checkin object
      def update_checkin(project_id, id, data)
        self.checkin_configs ||= {}
        if self.checkin_configs[project_id]&.[](id)
          self.checkin_configs[project_id][id] = data
          return data
        else
          raise "Update failed"
        end
      end

      # Delete checkin
      # @example
      #   backend.delete_checkin('1234', 'eajaj')
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @returns [Boolean] true if deletion was successful
      # @raises CheckinSyncError on error
      def delete_checkin(project_id, id)
        self.checkin_configs ||= {}
        if self.checkin_configs[project_id]&.[](id)
          self.checkin_configs[project_id].delete(id)
        else
          raise "Delete failed"
        end
      end
    end
  end
end
