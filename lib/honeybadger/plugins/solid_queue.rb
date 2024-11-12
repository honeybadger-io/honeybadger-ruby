module Honeybadger
  module Plugins
    module SolidQueue
      Plugin.register :solid_queue do
        requirement { config.load_plugin_insights?(:solid_queue) && defined?(::SolidQueue) }

        collect_solid_queue_stats = -> do
          data = {}
          data[:stats] = {
            jobs_in_progress: ::SolidQueue::ClaimedExecution.count,
            jobs_blocked: ::SolidQueue::BlockedExecution.count,
            jobs_failed: ::SolidQueue::FailedExecution.count,
            jobs_scheduled: ::SolidQueue::ScheduledExecution.count,
            jobs_processed: ::SolidQueue::Job.where.not(finished_at: nil).count,
            active_workers: ::SolidQueue::Process.where(kind: "Worker").count,
            active_dispatchers: ::SolidQueue::Process.where(kind: "Dispatcher").count
          }

          data[:queues] = {}

          ::SolidQueue::Queue.all.each do |queue|
            data[:queues][queue.name] = { depth: queue.size }
          end

          data
        end

        collect do
          stats = collect_solid_queue_stats.call

          if config.cluster_collection?(:solid_queue)
            if Honeybadger.config.load_plugin_insights_events?(:solid_queue)
              Honeybadger.event('stats.solid_queue', stats.except(:stats).merge(stats[:stats]))
            end

            if Honeybadger.config.load_plugin_insights_metrics?(:solid_queue)
              metric_source 'solid_queue'
              stats[:stats].each do |stat_name, value|
                gauge stat_name, value: value
              end

              stats[:queues].each do |queue_name, data|
                data.each do |key, value|
                  gauge "queue_#{key}", queue: queue_name, value: value
                end
              end
            end
          end
        end
      end
    end
  end
end
