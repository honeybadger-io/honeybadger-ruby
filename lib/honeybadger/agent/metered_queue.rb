module Honeybadger
  class Agent
    # Internal: A thread-safe first-in-first-out queue. Values are pushed onto
    # the queue and released at a defined interval.
    class MeteredQueue
      def initialize(interval = 1, max = 1000, now = now())
        @interval = interval
        @max = max
        @values = Array.new
        @throttles = Array.new
        @future = calculate_future(now, interval)
        @mutex = Mutex.new
      end

      def size
        mutex.synchronize { values.size }
      end

      def push(value)
        unless values.size == max
          mutex.synchronize { values.push(value) }
        end
      end

      def pop
        if now.to_i >= future
          mutex.synchronize do
            @future = calculate_future
            values.shift
          end
        end
      end

      def pop!
        mutex.synchronize { values.shift }
      end

      # Applies a new throttle to this queue and adjusts the future.
      #
      # Returns nothing
      def throttle(throttle)
        mutex.synchronize do
          old_interval = throttled_interval
          throttles << throttle
          @future += (throttled_interval - old_interval)
        end
      end

      # Removes the last throttle from this queue and adjusts the future.
      #
      # Returns Float throttle
      def unthrottle
        mutex.synchronize do
          old_interval = throttled_interval
          throttles.pop.tap do |throttle|
            if throttle
              @future -= (old_interval - throttled_interval)
            end
          end
        end
      end

      private

      attr_reader :interval, :max, :values, :throttles, :future, :mutex

      def now
        Time.now
      end

      def calculate_future(now = now(), interval = interval())
        now.to_i + throttled_interval(interval)
      end

      def throttled_interval(interval = interval())
        throttles.reduce(interval) {|a,e| a * e }
      end
    end
  end
end
