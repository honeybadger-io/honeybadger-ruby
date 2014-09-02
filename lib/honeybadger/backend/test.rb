require 'honeybadger/backend/null'

module Honeybadger
  module Backend
    class Test < Null
      # Public: The notification list.
      #
      # Examples:
      #
      #   backend.notifications[:notices] # => [Notice, Notice, ...]
      #
      # Returns the Hash notifications.
      def notifications
        @notifications ||= Hash.new([])
      end

      def notify(feature, payload)
        notifications[feature] = [] unless notifications.include?(feature)
        notifications[feature] << payload
        super
      end
    end
  end
end
