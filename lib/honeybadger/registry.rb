module Honeybadger
  class Registry
    def initialize
      @mutex = Mutex.new
      @metrics = {}
    end

    def register(metric)
      @mutex.synchronize do
        @metrics[metric.signature] = metric
      end
    end

    def get(metric_type, name, attributes)
      @mutex.synchronize do
        @metrics[Honeybadger::Metric.signature(metric_type, name, attributes)]
      end
    end

    def flush
      @mutex.synchronize do
        @metrics = {}
      end
    end

    def metrics
      @mutex.synchronize do
        @metrics.values
      end
    end
  end
end
