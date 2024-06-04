module Honeybadger
  class Metric
    attr_reader :name, :attributes, :samples

    def self.metric_type
      name.split('::').last.downcase
    end

    def self.signature(metric_type, name, attributes)
      Digest::SHA1.hexdigest("#{metric_type}-#{name}-#{attributes.keys.join('-')}-#{attributes.values.join('-')}").to_sym
    end

    def self.register(registry, metric_name, attributes)
      registry.get(metric_type, metric_name, attributes) ||
        registry.register(new(metric_name, attributes))
    end

    def initialize(name, attributes)
      @name = name
      @attributes = attributes || {}
      @samples = 0
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
        metric_name: name,
        metric_type: metric_type,
        samples: samples
      })
    end

    def event_payloads
      payloads.map do |payload|
        base_payload.merge(payload)
      end
    end
  end
end
