require 'securerandom'

module Honeybadger
  class Agent
    class Batch
      def initialize(config, name, opts = {})
        @id = SecureRandom.uuid
        @config = config
        @name = name
        @max = opts.fetch(:max, 100)
        @interval = opts.fetch(:interval, 60)
        @future = opts.fetch(:now, now()) + interval
        @values = opts.fetch(:collection, Array.new)
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
          { name => values.map(&:to_h), :environment => config[:env], :hostname => config[:hostname] }
        end
      end

      private

      attr_reader :config, :name, :max, :interval, :values, :future, :mutex

      def now
        Time.now.to_i
      end
    end
  end
end
