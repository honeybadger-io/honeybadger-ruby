module Breadcrumbs
  class RingBuffer
    attr_reader :buffer

    def initialize(buffer_size = 40)
      @buffer_size = buffer_size
      clear!
    end

    def add!(item)
      @buffer << item
      @ct += 1
      @buffer.shift(1) if @ct > @buffer_size
    end

    def clear!
      @buffer = []
      @ct = 0
    end
  end
end
