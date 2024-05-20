module Honeybadger
  class Registry
    def initialize
      @mutex = Mutex.new
      @metrics = Hash.new
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
        @metrics = Hash.new
      end
    end

    def metrics
      @mutex.synchronize do
        @metrics.values
      end
    end

    def debug_info
      "#{Thread.current.inspect} #{Honeybadger::Agent.instance.collector_worker} #{object_id} #{@metrics.object_id} #{metrics.count} #{metrics.map(&:signature)}"
    end
  end
end
