module Honeybadger
  class DevelopmentSender

    def initialize(options = {})
    end

    # Public: Sends the notice data off to no where.
    #
    # notice - The notice data to be sent (Hash or JSON string)
    #
    # Returns nil
    def send_to_honeybadger(notice)
      message = notice.is_a?(String) ? notice : notice.error_message
      Honeybadger.write_verbose_log(message, :debug)
    end

  end
end
