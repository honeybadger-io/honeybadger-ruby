require 'honeybadger/backend/base'

module Honeybadger
  module Backend
    class Null < Base
      def initialize(*args)
        super
      end

      def notify(feature, payload)
        Response.new(201, '{}')
      end
    end
  end
end
