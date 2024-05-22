module Honeybadger
  class RegistryExecution
    def initialize(registry, config, options)
      @registry = registry
      @config = config
      @options = options
      @ticks = @interval = config[:'insights.registry_flush_interval'] || options.fetch(:interval, 60)
    end

    def tick
      @ticks = @ticks - 1
    end

    def reset
      @ticks = @interval
      @registry.flush
    end

    def call
      @registry.metrics.each do |metric|
        metric.event_payloads.each do |payload|
          Honeybadger.event(payload.merge(interval: @interval))
        end
      end
    end
  end
end
