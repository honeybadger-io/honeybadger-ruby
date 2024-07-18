module Honeybadger
  module Plugins
    module SolidQueue
      Plugin.register :solid_queue do
        requirement { config.load_plugin_insights?(:solid_queue) && defined?(::SolidQueue) }

        collect do
          if config.cluster_collection?(:solid_queue)
            metric_source 'solid_queue'

            gauge 'jobs_in_progress', ->{ ::SolidQueue::ClaimedExecution.count }
            gauge 'jobs_blocked', ->{ ::SolidQueue::BlockedExecution.count }
            gauge 'jobs_failed', ->{ ::SolidQueue::FailedExecution.count }
            gauge 'jobs_scheduled', ->{ ::SolidQueue::ScheduledExecution.count }
            gauge 'jobs_processed', ->{ ::SolidQueue::Job.where.not(finished_at: nil).count }
            gauge 'active_workers', ->{ ::SolidQueue::Process.where(kind: "Worker").count }
            gauge 'active_dispatchers', ->{ ::SolidQueue::Process.where(kind: "Dispatcher").count }

            ::SolidQueue::Queue.all.each do |queue|
              gauge 'queue_depth', { queue: queue.name }, ->{ queue.size }
            end
          end
        end
      end
    end
  end
end
