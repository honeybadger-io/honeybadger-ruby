require 'forwardable'

# Internal: A collection for de-duping traces. Not currently thread-safe (so
# make sure access is synchronized.)
module Honeybadger
  class Agent
    class TraceCollection
      extend Forwardable
      include Enumerable

      def initialize
        @traces = {}
      end

      def_delegators :to_a, :each, :empty?, :size

      def push(trace)
        if !traces.key?(trace.key) || traces[trace.key].duration < trace.duration
          traces[trace.key] = trace
        end
      end

      def to_a
        traces.values
      end

      private

      attr_reader :traces
    end
  end
end
