require 'honeybadger/backend/base'

module Honeybadger
  module Backend
    class Null < Base
      def initialize(*args)
        super
        logger.warn('Initializing development backend: data will not be reported.')
      end

      def notify(feature, payload)
        Response.new(201, '{}')
      end
    end
  end
end
