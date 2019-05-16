require 'forwardable'

module Breadcrumbs
  class Collector
    extend Forwardable

    def_delegators :@buffer, :clear!, :add!

    # Manages breadcrumbs
    #
    def initialize(buffer = RingBuffer.new)
      @buffer = buffer
    end

    def crumbs
      @buffer.buffer
    end
  end
end
