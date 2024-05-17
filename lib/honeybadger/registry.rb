module Honeybadger
  class Registry
    def initialize
      @mutex = Mutex.new
      @metrics = Hash.new
    end

    def register(metric)
      @mutex.synchronize do
        @metrics[metric.name] ||= {}
        @metrics[metric.name][metric.attributes] = metric
      end
    end

    def get(name, attributes)
      @mutex.synchronize do
        @metrics[name] ||= {}
        @metrics[name][attributes]
      end
    end

    def flush
      @mutex.synchronize do
        @metrics = Hash.new
      end
    end

    def metrics
      @mutex.synchronize do
        @metrics.values.map(&:values).flatten
      end
    end
  end
end
