require 'honeybadger/backend/null'

module Honeybadger
  module Backend
    class Debug < Null
      def notify(feature, payload)
        logger.debug("notifying debug backend of feature=#{feature}\n\t#{payload.to_json}")
        super
      end
    end
  end
end
