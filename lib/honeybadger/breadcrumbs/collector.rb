require 'forwardable'

module Honeybadger
  module Breadcrumbs
    class Collector
      include Enumerable
      extend Forwardable
      # The Collector manages breadcrumbs and provides an interface for accessing
      # and affecting breadcrumbs
      #
      # Most actions are delegated to the current buffer implementation. A
      # Buffer must implement all delegated methods to work with the Collector.

      def_delegators :@buffer, :clear!, :add!, :<<, :each, :to_a

      def initialize(config, buffer = RingBuffer.new)
        @config = config
        @buffer = buffer
      end

      # Breadcrumb hash representation. Only contains active breadcrumbs. If
      # you want to remove a breadcrumb from the trail, then you can
      # selectively ignore breadcrumbs when building a notice.
      #
      # @return [Array] Filtered breadcrumbs
      def trail
        select(&:active?)
      end

      def to_h
        {
          trail: trail
        }
      end
    end
  end
end
