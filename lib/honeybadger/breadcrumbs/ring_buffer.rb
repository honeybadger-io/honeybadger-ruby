module Honeybadger
  module Breadcrumbs
    class RingBuffer
      # Simple ring buffer implementation that keeps item count constrained using
      # a rolling window. Items from the front of the buffer are dropped as more
      # are pushed on the end of the stack.
      include Enumerable

      def initialize(buffer_size = 40, collection: BreadcrumbsCollection)
        @buffer_size = buffer_size
        @collection = collection
        @ct = 0
      end

      def add!(item)
        @collection << item
        @ct += 1
        @collection.shift(1) if @ct > @buffer_size
      end

      def clear!
        @collection.clear
        @ct = 0
      end

      def buffer
        @collection.to_a
      end
      alias_method :to_a, :buffer

      def each(&blk)
        @collection.each(&blk)
      end

      def previous
        @collection.last
      end

      def drop
        @collection.pop
      end

      private

      # The collection must be duplicated when duplicating the buffer to prevent
      # conurrent modifications. This converts it to a plain array.
      def initialize_dup(source)
        @collection = source.to_a.dup
        super
      end
    end
  end
end
