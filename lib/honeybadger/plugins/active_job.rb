module Honeybadger
  module Plugins
    module ActiveJob
      # Ignore inline and test adapters, as well as the adapters that we support with their own plugins
      EXCLUDED_ADAPTERS = %i[inline test delayed_job faktory karafka resque shoryuken sidekiq sucker_punch].freeze

      class << self
        def perform_around(job, block)
          Honeybadger.clear!
          context = context(job)
          block.call
        rescue StandardError => e
          Honeybadger.notify(e, context: context, parameters: { arguments: job.arguments })
          raise e
        end

        def context(job)
          {
            component: job.class,
            enqueued_at: job.enqueued_at,
            executions: job.executions,
            job_class: job.class,
            job_id: job.job_id,
            priority: job.priority,
            queue_name: job.queue_name,
            scheduled_at: job.scheduled_at
          }
        end
      end

      Plugin.register do
        requirement do
          defined?(::Rails.application) &&
            ::Rails.application.config.respond_to?(:active_job) &&
            !EXCLUDED_ADAPTERS.include?(::Rails.application.config.active_job[:queue_adapter])
        end

        execution do
          ::ActiveJob::Base.set_callback(:perform, :around, &ActiveJob.method(:perform_around))
        end
      end
    end
  end
end
