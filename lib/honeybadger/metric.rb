module Honeybadger
  class Metric
    attr_reader :name, :attributes, :sampled

    def self.metric_type
      name.split('::').last.downcase
    end

    def self.signature(metric_type, name, attributes)
      "#{metric_type}-#{name}-#{attributes.keys.join('-')}-#{attributes.values.join('-')}".to_sym
    end

    def self.register(metric_name, attributes)
      Honeybadger.registry.get(metric_type, metric_name, attributes) ||
        Honeybadger.registry.register(new(metric_name, attributes))
    end

    def initialize(name, attributes)
      @name = name
      @attributes = attributes || {}
      @sampled = 0
    end

    def metric_type
      self.class.metric_type
    end

    def signature
      self.class.signature(metric_type, name, attributes)
    end

    def base_payload
      attributes.merge({
        event_type: "metric.hb",
        hostname: Honeybadger.config[:hostname].to_s,
        metric_name: name,
        metric_type: metric_type,
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