module Honeybadger
  module Breadcrumbs
    class Breadcrumb
      # Raw breadcrumb data structure
      #
      attr_reader :category, :timestamp
      attr_accessor :message, :metadata, :active

      include Comparable

      def initialize(category: "custom", message: nil, metadata: {})
        @active = true
        @timestamp = DateTime.now

        @category = category
        @message = message
        @metadata = metadata
      end

      def to_h
        {
          category: category,
          message: message,
          metadata: metadata,
          timestamp: timestamp
        }
      end

      def <=>(other)
        to_h <=> other.to_h
      end


      # Is the Breadcrumb active or not. Inactive Breadcrumbs not be included
      # with any outgoing payloads.
      #
      # @return [Boolean]
      def active?
        @active
      end

      # Sets the breadcrumb to inactive
      #
      # @return self
      def ignore!
        @active = false
        self
      end
    end
  end
end
