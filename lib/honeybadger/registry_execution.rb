module Honeybadger
  class RegistryExecution
    def initialize(registry, config, options)
      @registry = registry
      @config = config
      @options = options
      @interval = config[:'insights.registry_flush_interval'] || options.fetch(:interval, 60)
      @end_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) + @interval
    end

    def tick
      @end_time - ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end

    def reset
      @end_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) + @interval
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
