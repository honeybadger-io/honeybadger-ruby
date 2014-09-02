require 'honeybadger/backend/null'

module Honeybadger
  module Backend
    class Debug < Null
      def notify(feature, payload)
        logger.debug(sprintf("notifying debug backend of feature=%s\n\t#{payload.to_json}", feature))
        super
      end
    end
  end
end
