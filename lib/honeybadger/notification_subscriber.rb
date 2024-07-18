require 'honeybadger/instrumentation_helper'
require 'honeybadger/util/sql'

module Honeybadger
  class NotificationSubscriber
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
      Honeybadger.event(name, payload)
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
  end

  class ActiveSupportCacheSubscriber < NotificationSubscriber
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
        query: Util::SQL.obfuscate(payload[:sql], payload[:connection].adapter_name),
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

  class ActiveJobMetricsSubscriber < NotificationSubscriber
    include Honeybadger::InstrumentationHelper

    def format_payload(payload)
      {
        job_class: payload[:job].class.to_s,
        queue_name: payload[:job].queue_name
      }
    end

    def record(name, payload)
      metric_source 'active_job'
      histogram name, { bins: [30, 60, 120, 300, 1800, 3600, 21_600] }.merge(payload)
    end
  end

  class ActionMailerSubscriber < NotificationSubscriber
  end

  class ActiveStorageSubscriber < NotificationSubscriber
  end
end
