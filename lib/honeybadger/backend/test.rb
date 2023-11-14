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

      def self.check_in_configs
        @check_in_configs ||= {}
      end

      def check_in_configs
        self.class.check_in_configs
      end

      # Set check_in by id, only for use in tests
      # @example
      #   backend.set_checkin('1234', 'ajdja', check_in)
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @param [CheckIn] data CheckIn object with config
      def set_checkin(project_id, id, data)
        self.check_in_configs[project_id] = self.check_in_configs[project_id] || {}
        self.check_in_configs[project_id][id] = data
      end

      # Get check_in by id
      # @example
      #   backend.get_check_in('1234', 'ajdja")
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @returns [CheckIn] or nil if check_in is not found
      def get_check_in(project_id, id)
        self.check_in_configs ||= {}
        self.check_in_configs[project_id]&.[](id)
      end

      # Get checkins by project
      # @example
      #   backend.get_check_ins('1234')
      #
      # @param [String] project_id The unique project id
      # @returns [Array<CheckIn>] All checkins for this project
      def get_check_ins(project_id)
        self.check_in_configs ||= {}
        self.check_in_configs[project_id] = self.check_in_configs[project_id] || {}
        return [] if self.check_in_configs[project_id].empty?
        self.check_in_configs[project_id].values
      end

      # Create check_in on project
      # @example
      #   backend.create_check_in('1234', check_in)
      #
      # @param [String] project_id The unique project id
      # @param [CheckIn] data A CheckIn object encapsulating the config
      # @returns [CheckIn] A check_in object containing the id
      def create_check_in(project_id, data)
        self.check_in_configs ||= {}
        self.check_in_configs[project_id] = self.check_in_configs[project_id] || {}
        id = self.check_in_configs[project_id].length + 1
        loop do
          break unless self.check_in_configs[project_id].has_key?(id)
          id += 1
        end
        id = id.to_s
        data.id = id
        self.check_in_configs[project_id][id] = data
        data
      end

      # Update check_in on project
      # @example
      #   backend.update_check_in('1234', 'eajaj', check_in)
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @param [CheckIn] data A CheckIn object encapsulating the config
      # @returns [CheckIn] updated CheckIn object
      def update_check_in(project_id, id, data)
        self.check_in_configs ||= {}
        if self.check_in_configs[project_id]&.[](id)
          self.check_in_configs[project_id][id] = data
          return data
        else
          raise "Update failed"
        end
      end

      # Delete check_in
      # @example
      #   backend.delete_check_in('1234', 'eajaj')
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @returns [Boolean] true if deletion was successful
      # @raises CheckInSyncError on error
      def delete_check_in(project_id, id)
        self.check_in_configs ||= {}
        if self.check_in_configs[project_id]&.[](id)
          self.check_in_configs[project_id].delete(id)
        else
          raise "Delete failed"
        end
      end
    end
  end
end
