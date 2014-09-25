require 'honeybadger/backend/null'

module Honeybadger
  module Backend
    class Test < Null
      # Public: The notification list.
      #
      # Examples:
      #
      #   Test.notifications[:notices] # => [Notice, Notice, ...]
      #
      # Returns the Hash notifications.
      def self.notifications
        @notifications ||= Hash.new {|h,k| h[k] = [] }
      end

      # Internal: Local helper.
      def notifications
        self.class.notifications
      end

      def notify(feature, payload)
        notifications[feature] << payload
        super
      end
    end
  end
end
