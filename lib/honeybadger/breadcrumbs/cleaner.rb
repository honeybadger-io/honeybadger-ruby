require 'set'

module Honeybadger
  module Breadcrumbs
    # @api private
    # Responsible for ensuring we are storing and sending sane breadcrumb data
    class Cleaner
      VALID_TYPES = Set[
        TrueClass, FalseClass, BigDecimal, Integer, Float, String, Symbol
      ].freeze

      def initialize(config)
        @config = config
      end

      def clean!(breadcrumb)
        breadcrumb.metadata.keep_if(&method(:valid_metadata?))
      end

      private

      def valid_metadata?(k, v)
        return true if allowed_metadata_type?(v)
        @config.logger.debug("Removed metadata key '#{k}' from breadcrumb because value was invalid")
        false
      end

      def allowed_metadata_type?(value)
        VALID_TYPES.include?(value.class)
      end
    end
  end
end
