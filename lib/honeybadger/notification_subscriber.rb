require 'honeybadger/instrumentation_helper'
require 'honeybadger/util/sql'

module Honeybadger
  class NotificationSubscriber
    include Honeybadger::InstrumentationHelper

    def start(name, id, payload)
      payload[:_start_time] = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end

    def finish(name, id, payload)
      finish_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      return unless process?(name, payload)

      payload = {
        instrumenter_id: id,
        duration: ((finish_time - payload.delete(:_start_time)) * 1000).round(2)
      }.merge(format_payload(payload).compact)

      record(name, payload)
    end

    def record(name, payload)
      if Honeybadger.config.load_plugin_insights_events?(:rails)
        Honeybadger.event(name, payload)
      end

      if Honeybadger.config.load_plugin_insights_metrics?(:rails)
        metric_source 'rails'
        record_metrics(name, payload)
      end
    end

    def record_metrics(name, payload)
      case name
      when 'sql.active_record'
        gauge('duration.sql.active_record', value: payload[:duration], **payload.slice(:query))
      when 'process_action.action_controller'
        gauge('duration.process_action.action_controller', value: payload[:duration], **payload.slice(:method, :controller, :action, :format, :status))
        gauge('db_runtime.process_action.action_controller', value: payload[:db_runtime], **payload.slice(:method, :controller, :action, :format, :status))
        gauge('view_runtime.process_action.action_controller', value: payload[:view_runtime], **payload.slice(:method, :controller, :action, :format, :status))
      when 'perform.active_job'
        gauge('duration.perform.active_job', value: payload[:duration], **payload.slice(:job_class, :queue_name))
      when /^cache_.*.active_support$/
        gauge("duration.#{name}", value: payload[:duration], **payload.slice(:store, :key))
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
