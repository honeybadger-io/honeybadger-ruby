require "honeybadger/notification_subscriber"
require "honeybadger/instrumentation_helper"

module Honeybadger
  module Plugins
    module ActiveJob
      # Ignore the adapters that we support with their own plugins
      EXCLUDED_ADAPTERS = %i[delayed_job faktory karafka resque shoryuken sidekiq sucker_punch]

      @mutex = Mutex.new
      @counters = Hash.new(0)
      @queue_counters = Hash.new { |h, k| h[k] = Hash.new(0) }

      class << self
        def perform_around(job, block)
          Honeybadger.clear!
          context = context(job)
          block.call
        rescue => e
          if job.executions >= Honeybadger.config[:"active_job.attempt_threshold"].to_i
            Honeybadger.notify(
              e,
              context: context,
              parameters: {arguments: job.arguments}
            )
          end
          raise e
        end

        def context(job) # rubocop:disable Metrics/MethodLength
          {
            component: job.class,
            action: "perform",
            enqueued_at: job.try(:enqueued_at),
            executions: job.executions,
            job_class: job.class,
            job_id: job.job_id,
            priority: job.priority,
            queue_name: job.queue_name,
            scheduled_at: job.scheduled_at
          }
        end

        def record_metric(name, payload)
          @mutex.synchronize do
            case name
            when "perform.active_job"
              queue = payload[:queue_name] || "default"
              @counters[:jobs_performed] += 1
              @queue_counters[queue][:performed] += 1
              if payload[:status] == "failure"
                @counters[:jobs_failed] += 1
                @queue_counters[queue][:failed] += 1
              end
            when "enqueue.active_job", "enqueue_at.active_job"
              queue = payload[:queue_name] || "default"
              @counters[:jobs_enqueued] += 1
              @queue_counters[queue][:enqueued] += 1
            when "enqueue_all.active_job"
              if payload[:jobs].is_a?(Array)
                payload[:jobs].each do |job_info|
                  queue = job_info[:queue_name] || "default"
                  @counters[:jobs_enqueued] += 1
                  @queue_counters[queue][:enqueued] += 1
                end
              end
            when "enqueue_retry.active_job"
              queue = payload[:queue_name] || "default"
              @counters[:jobs_retried] += 1
              @queue_counters[queue][:retried] += 1
            when "discard.active_job"
              queue = payload[:queue_name] || "default"
              @counters[:jobs_discarded] += 1
              @queue_counters[queue][:discarded] += 1
            when "retry_stopped.active_job"
              queue = payload[:queue_name] || "default"
              @counters[:jobs_retry_stopped] += 1
              @queue_counters[queue][:retry_stopped] += 1
            end
          end
        end

        def flush_counters
          @mutex.synchronize do
            data = {
              stats: @counters.dup,
              queues: @queue_counters.each_with_object({}) { |(k, v), h| h[k] = v.dup }
            }
            @counters.clear
            @queue_counters.clear
            data
          end
        end

        def reset_counters!
          @mutex.synchronize do
            @counters.clear
            @queue_counters.clear
          end
        end
      end

      Plugin.register :active_job do
        requirement do
          defined?(::Rails.application) &&
            ::Rails.application.config.respond_to?(:active_job) &&
            ::Rails.application.config.active_job[:queue_adapter].respond_to?(:to_sym) &&
            !EXCLUDED_ADAPTERS.include?(::Rails.application.config.active_job[:queue_adapter].to_sym)
        end

        # Don't report errors if GoodJob is reporting them
        requirement do
          !::Rails.application.config.active_job[:queue_adapter].to_s.match?(/(GoodJob::Adapter|good_job)/) ||
            !::Rails.application.config.respond_to?(:good_job) ||
            ::Rails.application.config.good_job[:on_thread_error].nil?
        end

        execution do
          if Honeybadger.config[:"exceptions.enabled"]
            ::ActiveSupport.on_load(:active_job) do
              ::ActiveJob::Base.set_callback(:perform, :around, prepend: true, &ActiveJob.method(:perform_around))
            end
          end

          if config.load_plugin_insights?(:active_job)
            ::ActiveSupport::Notifications.subscribe(/(enqueue_at|enqueue|enqueue_retry|enqueue_all|perform|retry_stopped|discard)\.active_job/, Honeybadger::ActiveJobSubscriber.new)
          end
        end

        collect do
          if Honeybadger.config.load_plugin_insights?(:active_job, feature: :metrics)
            data = ActiveJob.flush_counters

            next if data[:stats].empty?

            if Honeybadger.config.load_plugin_insights?(:active_job, feature: :events)
              Honeybadger.event("stats.active_job", data.except(:stats).merge(data[:stats]))
            end

            metric_source "active_job"
            data[:stats].each do |stat_name, value|
              gauge stat_name, value: value
            end

            data[:queues].each do |queue_name, counters|
              counters.each do |key, value|
                gauge "queue_#{key}", queue: queue_name, value: value
              end
            end
          end
        end
      end
    end
  end
end
