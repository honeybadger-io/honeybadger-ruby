require 'forwardable'

module Breadcrumbs
  class Collector
    include Enumerable
    extend Forwardable
    # The Collector manages breadcrumbs and provides an interface for accessing
    # and affecting breadcrumbs
    #

    def_delegators :@buffer, :clear!, :add!, :each

    def initialize(config, buffer = RingBuffer.new)
      @config = config
      @buffer = buffer
    end

    # Returns a raw array of breadcrumb objects
    #
    # @return [Array]
    def crumbs
      @buffer.to_a
    end
  end
end
