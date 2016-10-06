module Honeybadger
  module Backend
    # Internal: Logs the notice payload rather than sending it. The purpose of
    # this backend is primarily for programmatically inspecting JSON payloads
    # in integration tests.
    class Debug < Null
      def notify(feature, payload)
        logger.unknown("notifying debug backend of feature=#{feature}\n\t#{payload.to_json}")
        return Response.new(ENV['DEBUG_BACKEND_STATUS'].to_i, nil) if ENV['DEBUG_BACKEND_STATUS']
        super
      end
    end
  end
end
