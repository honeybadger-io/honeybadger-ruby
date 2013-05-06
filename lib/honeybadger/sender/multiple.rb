module Honeybadger
  class Sender

    # A Sender backend that delegates to multiple senders.  Inspired by
    # Resque::Failure::Multiple.

    class Multiple

      class << self
        attr_accessor :classes
      end

      def initialize(options = {})
        @options = options
      end

      # Public: Sends the notice data off to Honeybadger for processing.
      #
      # notice - The notice data to be sent (Hash or JSON string)
      #
      # Returns error id from successful response
      def send_to_honeybadger(notice)
        @backends = self.class.classes.map {|klass| klass.new(@options)}
        Hash[*@backends.map{ |backend| [backend.class, backend.send_to_honeybadger(notice)] }.flatten]
      end

    end
  end
end
