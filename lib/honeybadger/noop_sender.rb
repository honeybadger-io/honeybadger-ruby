module Honeybadger
  class NoopSender

    def initialize(options = {})
    end

    # Public: Sends the notice data off to no where.
    #
    # notice - The notice data to be sent (Hash or JSON string)
    #
    # Returns nil
    def send_to_honeybadger(notice)
      puts "?" * 80
      #puts notice.inspect
      #puts "?" * 80
    end

  end
end
