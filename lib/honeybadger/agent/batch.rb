require 'securerandom'

module Honeybadger
  class Agent
    class Batch
      def initialize(config, name = :data, max = 100, interval = 60, now = now)
        @id = SecureRandom.uuid
        @config = config
        @name = name
        @max = max
        @interval = interval
        @future = now + interval
        @values = Array.new
        @mutex = Mutex.new
      end

      attr_reader :id

      def push(val)
        mutex.synchronize { values.push(val) }
      end

      def empty?
        mutex.synchronize { values.empty? }
      end

      def size
        mutex.synchronize { values.size }
      end

      def flush?
        size >= max || now >= future
      end

      def as_json(*args)
        mutex.synchronize do
          { name => values.compact.map(&:to_h), :environment => config[:env], :hostname => config[:hostname] }
        end
      end

      private

      attr_reader :config, :name, :max, :values, :future, :mutex

      def now
        Time.now.to_i
      end
    end
  end
end
