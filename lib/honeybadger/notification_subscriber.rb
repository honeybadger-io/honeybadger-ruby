require 'honeybadger/instrumentation_helper'
require 'honeybadger/util/sql'

module Honeybadger
  class NotificationSubscriber
    include Honeybadger::InstrumentationHelper

    Metric = Struct.new(:type, :event, :value_key, :context)

    RAILS_METRICS = [
      Metric.new(:gauge, 'sql.active_record', :duration, %i[query]),

      Metric.new(:gauge, 'process_action.action_controller', :duration, %i[method controller action format status]),
      Metric.new(:gauge, 'process_action.action_controller', :db_runtime, %i[method controller action format status]),
      Metric.new(:gauge, 'process_action.action_controller', :view_runtime, %i[method controller action format status]),

      Metric.new(:gauge, 'cache_read.active_support', :duration, %i[store key]),
      Metric.new(:gauge, 'cache_fetch_hit.active_support', :duration, %i[store key]),
      Metric.new(:gauge, 'cache_write.active_support', :duration, %i[store key]),
      Metric.new(:gauge, 'cache_exist?.active_support', :duration, %i[store key]),

      Metric.new(:gauge, 'render_partial.action_view', :duration, %i[view]),
      Metric.new(:gauge, 'render_template.action_view', :duration, %i[view]),
      Metric.new(:gauge, 'render_collection.action_view', :duration, %i[view]),

      Metric.new(:gauge, 'perform.active_job', :duration, %i[job_class queue_name])
    ]

    def start(name, id, payload)
      @start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end

    def finish(name, id, payload)
      @finish_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      return unless process?(name, payload)

      payload = {
        instrumenter_id: id,
        duration: ((@finish_time - @start_time) * 1000).round(2)
      }.merge(format_payload(payload).compact)

      record(name, payload)
    end

    def record(name, payload)
      if Honeybadger.config.load_plugin_insights_events?(:rails)
        Honeybadger.event(name, payload)
      end

      if Honeybadger.config.load_plugin_insights_metrics?(:rails) && (metrics = find_metrics(name, payload))
        metric_source 'rails'
        metrics.each do |metric|
          public_send(
            metric.type,
            [metric.value_key, metric.event].join('.'),
            value: payload[metric.value_key],
            **payload.slice(*metric.context)
          )
        end
      end
    end

    def find_metrics(name, payload)
      RAILS_METRICS.select do |metric|
        metric.event.to_s == name.to_s && payload.keys.include?(metric.value_key) && (payload.keys & metric.context).any?
      end
    end

    def process?(event, payload)
      true
    end

    def format_payload(payload)
      payload
    end
  end

  class ActionControllerSubscriber < NotificationSubscriber
    def format_payload(payload)
      payload.except(:headers, :request, :response)
    end
  end

  class ActionControllerCacheSubscriber < NotificationSubscriber
    def format_payload(payload)
      payload[:key] = ::ActiveSupport::Cache.expand_cache_key(payload[:key]) if payload[:key]
      payload
    end
  end

  class ActiveSupportCacheSubscriber < NotificationSubscriber
    def format_payload(payload)
      payload[:key] = ::ActiveSupport::Cache.expand_cache_key(payload[:key]) if payload[:key]
      payload
    end
  end

  class ActiveSupportCacheMultiSubscriber < NotificationSubscriber
    def format_payload(payload)
      payload[:key] = expand_cache_keys_from_payload(payload[:key])
      payload[:hits] = expand_cache_keys_from_payload(payload[:hits])
      payload
    end

    def expand_cache_keys_from_payload(data)
      return unless data

      data = data.keys if data.is_a?(Hash)

      Array(data).map do |k|
        ::ActiveSupport::Cache.expand_cache_key(k)
      end
    end
  end

  class ActionViewSubscriber < NotificationSubscriber
    PROJECT_ROOT = defined?(::Rails) ? ::Rails.root.to_s : ''

    def format_payload(payload)
      {
        view: payload[:identifier].to_s.gsub(PROJECT_ROOT, '[PROJECT_ROOT]'),
        layout: payload[:layout]
      }
    end
  end

  class ActiveRecordSubscriber < NotificationSubscriber
    def format_payload(payload)
      {
        query: Util::SQL.obfuscate(payload[:sql], payload[:connection]&.adapter_name),
        async: payload[:async]
      }
    end

    def process?(event, payload)
      return false if payload[:name] == "SCHEMA"
      true
    end
  end

  class ActiveJobSubscriber < NotificationSubscriber
    def format_payload(payload)
      job = payload[:job]
      adapter = payload[:adapter]
      payload.except(:job, :adapter).merge({
        adapter_class: adapter.class.to_s,
        job_class: job.class.to_s,
        job_id: job.job_id,
        queue_name: job.queue_name
      })
    end
  end

  class ActionMailerSubscriber < NotificationSubscriber
  end

  class ActiveStorageSubscriber < NotificationSubscriber
  end
end
