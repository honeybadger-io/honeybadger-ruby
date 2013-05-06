module Honeybadger
  class Sender
    class Test

      attr_reader :notices

      def initialize(options = {})
        @notices = []
      end

      # Public: Appends the notice to the #notices array attribute.
      #
      # notice - The notice data to be sent (Hash or JSON string)
      #
      # Returns nil
      def send_to_honeybadger(notice)
        @notices << notice
      end

    end
  end
end
