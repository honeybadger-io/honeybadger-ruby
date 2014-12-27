require 'securerandom'
require 'forwardable'

module Honeybadger
  class Agent
    autoload :MetricsCollection, 'honeybadger/agent/metrics_collection'

    class MetricsCollector
      extend Forwardable

      class Chunk
        extend Forwardable

        attr_reader :id

        def initialize(id, metrics)
          @id = SecureRandom.uuid
          @metrics = metrics
        end

        def_delegators :@metrics, :to_json, :size
      end

      def initialize(config, interval = 60, now = now())
        @id = SecureRandom.uuid
        @config = config
        @interval = interval
        @future = now + interval
        @mutex = Mutex.new
        @metrics = { :timing => {}, :counter => {} }
      end

      attr_reader :id

      def_delegators :@metrics, :[]

      def timing(name, value)
        add_metric(name, value, :timing)
      end

      def increment(name, value)
        add_metric(name, value, :counter)
      end

      def flush?
        now >= future
      end

      def size
        mutex.synchronize do
          metrics.reduce(0) do |count, hash|
            count + hash[1].size
          end
        end
      end

      def to_a
        mutex.synchronize do
          [].tap do |m|
            metrics[:counter].each do |metric, values|
              m << "#{metric} #{values.sum}"
            end
            metrics[:timing].each do |metric, values|
              m << "#{metric}:mean #{values.mean}"
              m << "#{metric}:median #{values.median}"
              m << "#{metric}:percentile_90 #{values.percentile(90)}"
              m << "#{metric}:min #{values.min}"
              m << "#{metric}:max #{values.max}"
              m << "#{metric}:stddev #{values.standard_dev}" if values.count > 1
              m << "#{metric} #{values.count}"
            end
            m.compact!
          end
        end
      end

      def chunk(size)
        to_a.each_slice(size) do |metrics|
          yield(Chunk.new(id, as_json(metrics)))
        end
      end

      def as_json(metrics = to_a)
        {metrics: metrics, :environment => config[:env], :hostname => config[:hostname]}
      end

      def to_json(*args)
        as_json.to_json(*args)
      end

      private

      attr_reader :config, :future, :metrics, :mutex

      def now
        Time.now.to_i
      end

      def add_metric(name, value, kind)
        mutex.synchronize do
          (metrics[kind][name] ||= MetricsCollection.new) << value
        end
      end
    end
  end
end
