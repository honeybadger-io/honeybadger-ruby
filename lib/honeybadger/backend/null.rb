require 'honeybadger/backend/base'

module Honeybadger
  module Backend
    class Null < Base
      class StubbedResponse < Response
        def initialize(successful: true)
          super(:stubbed, '{}'.freeze)
          @success = successful
        end

        def success?
          @success
        end
      end

      def initialize(*args)
        super
      end

      def notify(feature, payload)
        StubbedResponse.new
      end

      def check_in(id)
        StubbedResponse.new
      end
    end
  end
end
