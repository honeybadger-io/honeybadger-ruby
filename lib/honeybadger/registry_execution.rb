module Honeybadger
  class RegistryExecution
    def initialize(config, options)
      @config = config
      @options = options
      @ticks = @interval = config[:'insights.registry_flush_interval'] || options.fetch(:interval, 60)
    end

    def tick
      @ticks = @ticks - 1
    end

    def reset
      @ticks = @interval
      Honeybadger.registry.flush
    end

    def register!
      Honeybadger.collect(self)
    end

    def call
      Honeybadger.registry.metrics.each do |metric|
        metric.event_payloads.each do |payload|
          Honeybadger.event(payload.merge(interval: @interval))
        end
      end
    end
  end
end
