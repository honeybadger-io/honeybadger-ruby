require 'honeybadger/backend/null'

module Honeybadger
  module Backend
    class Test < Null
      # Public: The notification list.
      #
      # Examples
      #
      #   Test.notifications[:notices] # => [Notice, Notice, ...]
      #
      # Returns the Hash notifications.
      def self.notifications
        @notifications ||= Hash.new {|h,k| h[k] = [] }
      end

      # Public: The check in list.
      #
      # Examples
      #
      #   Test.check_ins # => ["foobar", "danny", ...]
      #
      # Returns the Array of check ins.
      def self.check_ins
        @check_ins ||= []
      end

      # Internal: Local helper.
      def notifications
        self.class.notifications
      end

      # Internal: Local helper.
      def check_ins
        self.class.check_ins
      end

      def notify(feature, payload)
        notifications[feature] << payload
        super
      end

      def check_in(id)
        check_ins << id
      end
    end
  end
end
