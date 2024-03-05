module Honeybadger
  module Plugins
    module ActiveJob
      # Ignore inline and test adapters, as well as the adapters that we support with their own plugins
      EXCLUDED_ADAPTERS = %i[inline test delayed_job faktory karafka resque shoryuken sidekiq sucker_punch].freeze

      Plugin.register {
        requirement { defined?(::Rails.application) && ::Rails.application }
        requirement {
          ::Rails.application.config.respond_to?(:active_job) &&
            !EXCLUDED_ADAPTERS.include?(::Rails.application.config.active_job[:queue_adapter])
        }

        execution {
          ::ActiveJob::Base.class_eval do |base|
            base.set_callback :perform, :around do |param, block|
              Honeybadger.clear!
              begin
                block.call
              rescue => error
                Honeybadger.notify(error, parameters: {job_id: job_id, arguments: arguments})
                raise error
              end
            end
          end
        }
      }
    end
  end
end
