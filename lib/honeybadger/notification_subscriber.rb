require 'honeybadger/instrumentation_helper'

module Honeybadger
  class NotificationSubscriber
    def start(name, id, payload)
      @start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end

    def finish(name, id, payload)
      @finish_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      return unless process?(name)

      payload = {
        instrumenter_id: id,
        duration: ((@finish_time - @start_time) * 1000).round(2)
      }.merge(format_payload(payload).compact)

      record(name, payload)
    end

    def record(name, payload)
      Honeybadger.event(name, payload)
    end

    def process?(event)
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
    ESCAPE_QUOTES = /(\\"|\\')/
    SQUOTE_DATA = /'(?:[^']|'')*'/
    DQUOTE_DATA = /"(?:[^"]|"")*"/
    NUMBER_DATA = /\b\d+\b/
    DOUBLE_QUOTERS = /(postgres|sqlite|postgis)/i

    def format_payload(payload)
      {
        query: sanitize_query(payload[:sql], payload[:connection].adapter_name).strip,
        async: payload[:async]
      }
    end

    def sanitize_query(query, adapter_name = nil)
      query.to_s.gsub(/\s+/, " ").tap do |s|
        s.gsub!(ESCAPE_QUOTES, "".freeze)
        s.gsub!(SQUOTE_DATA, "'?'".freeze)
        s.gsub!(DQUOTE_DATA, '"?"'.freeze) unless adapter_name.to_s.match?(DOUBLE_QUOTERS)
        s.gsub!(NUMBER_DATA, "?".freeze)
      end
    end
  end

  class ActiveJobSubscriber < NotificationSubscriber
    def format_payload(payload)
      job = payload[:job]
      payload.except(:job).merge({
        job_class: job.class,
        job_id: job.job_id,
        queue_name: job.queue_name
      })
    end
  end

  class ActiveJobMetricsSubscriber < NotificationSubscriber
    include Honeybadger::InstrumentationHelper

    def format_payload(payload)
      {
        job_class: payload[:job].class,
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
