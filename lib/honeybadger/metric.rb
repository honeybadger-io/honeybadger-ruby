module Honeybadger
  class Metric
    attr_reader :name, :attributes, :sampled

    def self.register(name, attributes)
      Honeybadger.registry.get(name, attributes) ||
        Honeybadger.registry.register(new(name, attributes))
    end

    def initialize(name, attributes)
      @name = name
      @attributes = attributes || {}
      @sampled = 0
    end

    def base_payload
      attributes.merge({
        event_type: "hb.metrics",
        hostname: Honeybadger.config[:hostname].to_s,
        metric_name: name,
        metric_type: self.class.name.split('::').last.downcase,
        sampled: sampled
      })
    end

    def event_payloads
      payloads.map do |payload|
        base_payload.merge(payload)
      end
    end
  end
end
