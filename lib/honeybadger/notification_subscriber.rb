require "honeybadger/instrumentation_helper"
require "honeybadger/util/sql"

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
      }.merge(format_payload(name, payload).compact)

      record(name, payload)
      record_metrics(name, payload)
    end

    def record(name, payload)
      Honeybadger.event(name, payload)
    end

    def record_metrics(name, payload)
      # noop
    end

    def process?(name, payload)
      true
    end

    def format_payload(name, payload)
      payload
    end
  end

  class RailsSubscriber < NotificationSubscriber
    def record(name, payload)
      return unless Honeybadger.config.load_plugin_insights?(:rails, feature: :events)
      Honeybadger.event(name, payload)
    end

    def record_metrics(name, payload)
      return unless Honeybadger.config.load_plugin_insights?(:rails, feature: :metrics)

      metric_source "rails"

      case name
      when "sql.active_record"
        gauge("duration.sql.active_record", value: payload[:duration], **payload.slice(:query))
      when "process_action.action_controller"
        gauge("duration.process_action.action_controller", value: payload[:duration], **payload.slice(:method, :controller, :action, :format, :status))
        gauge("db_runtime.process_action.action_controller", value: payload[:db_runtime], **payload.slice(:method, :controller, :action, :format, :status))
        gauge("view_runtime.process_action.action_controller", value: payload[:view_runtime], **payload.slice(:method, :controller, :action, :format, :status))
      when "perform.active_job"
        gauge("duration.perform.active_job", value: payload[:duration], **payload.slice(:job_class, :queue_name))
      when /^cache_.*.active_support$/
        gauge("duration.#{name}", value: payload[:duration], **payload.slice(:store, :key))
      end
    end
  end

  class ActionControllerSubscriber < RailsSubscriber
    def format_payload(_name, payload)
      payload.except(:headers, :request, :response)
    end
  end

  class ActionControllerCacheSubscriber < RailsSubscriber
    def format_payload(_name, payload)
      payload[:key] = ::ActiveSupport::Cache.expand_cache_key(payload[:key]) if payload[:key]
      payload
    end
  end

  class ActiveSupportCacheSubscriber < RailsSubscriber
    def format_payload(_name, payload)
      payload[:key] = ::ActiveSupport::Cache.expand_cache_key(payload[:key]) if payload[:key]
      payload
    end
  end

  class ActiveSupportCacheMultiSubscriber < RailsSubscriber
    def format_payload(_name, payload)
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

  class ActionViewSubscriber < RailsSubscriber
    PROJECT_ROOT = defined?(::Rails) ? ::Rails.root.to_s : ""

    def format_payload(_name, payload)
      {
        view: payload[:identifier].to_s.gsub(PROJECT_ROOT, "[PROJECT_ROOT]"),
        layout: payload[:layout]
      }
    end
  end

  class ActiveRecordSubscriber < RailsSubscriber
    def format_payload(_name, payload)
      {
        query: Util::SQL.obfuscate(payload[:sql], payload[:connection]&.adapter_name),
        cached: payload[:cached],
        async: payload[:async]
      }
    end

    def process?(name, payload)
      return false if payload[:name] == "SCHEMA"
      true
    end
  end

  class ActiveJobSubscriber < RailsSubscriber
    def format_payload(name, payload)
      job = payload[:job]
      jobs = payload[:jobs]
      adapter = payload[:adapter]

      base_payload = payload.except(:job, :jobs, :adapter).merge({
        adapter_class: adapter&.class&.to_s
      })

      # Add status for perform events based on whether an exception occurred
      if name == "perform.active_job"
        base_payload[:status] = payload[:exception_object] ? "failure" : "success"
      end

      if jobs
        base_payload.merge({
          jobs: jobs.compact.map { |j| {job_class: j.class.to_s, job_id: j.job_id, queue_name: j.queue_name} }
        })
      elsif job
        base_payload.merge({
          job_class: job.class.to_s,
          job_id: job.job_id,
          queue_name: job.queue_name
        })
      else
        base_payload
      end
    end
  end

  class ActionMailerSubscriber < RailsSubscriber
    def format_payload(_name, payload)
      # Don't include the mail object in the payload...
      mail = payload.delete(:mail)

      # ... but do include any attachment filenames
      attachment_info = if mail&.attachments&.any?
        {attachments: mail.attachments.map { |a| {filename: a.filename} }}
      else
        {}
      end

      payload.merge(attachment_info)
    end
  end

  class ActiveStorageSubscriber < RailsSubscriber
  end
end
