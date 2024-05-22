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
        query: payload[:sql].to_s.gsub(/\s+/, ' ').strip,
        async: payload[:async]
      }
    end
  end

  class ActiveJobSubscriber < NotificationSubscriber
    def format_payload(payload)
      job = payload.delete(:job)
      payload.merge({
        job_class: job.class,
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
