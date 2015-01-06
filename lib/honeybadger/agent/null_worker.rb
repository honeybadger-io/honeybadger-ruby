module Honeybadger
  class Agent
    # Internal: A default worker which does nothing.
    class NullWorker
      def push(obj)
        true
      end

      def shutdown
        true
      end

      def shutdown!
        true
      end

      def flush
        true
      end

      def start
        true
      end
    end
  end
end
