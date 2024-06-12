require 'honeybadger/notification_subscriber'

module Honeybadger
  module Plugins
    module ActiveJob
      # Ignore inline and test adapters, as well as the adapters that we support with their own plugins
      EXCLUDED_ADAPTERS = %i[inline test delayed_job faktory karafka resque shoryuken sidekiq sucker_punch]

      class << self
        def perform_around(job, block)
          Honeybadger.clear!
          context = context(job)
          block.call
        rescue StandardError => e
          Honeybadger.notify(
            e,
            context: context,
            parameters: { arguments: job.arguments }
          ) if job.executions >= Honeybadger.config[:'active_job.attempt_threshold'].to_i
          raise e
        end

        def context(job) # rubocop:disable Metrics/MethodLength
          {
            component: job.class,
            action: 'perform',
            enqueued_at: job.try(:enqueued_at),
            executions: job.executions,
            job_class: job.class,
            job_id: job.job_id,
            priority: job.priority,
            queue_name: job.queue_name,
            scheduled_at: job.scheduled_at
          }
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
          ::ActiveJob::Base.set_callback(:perform, :around, &ActiveJob.method(:perform_around))

          if config.load_plugin_insights?(:active_job)
            ::ActiveSupport::Notifications.subscribe(/(enqueue_at|enqueue|enqueue_retry|enqueue_all|perform|retry_stopped|discard)\.active_job/, Honeybadger::ActiveJobSubscriber.new)
            ::ActiveSupport::Notifications.subscribe('perform.active_job', Honeybadger::ActiveJobMetricsSubscriber.new)
          end
        end
      end
    end
  end
end
