require 'honeybadger/plugin'
require 'honeybadger/ruby'

module Honeybadger
  module Plugins
    module Faktory
      class Middleware
        def call(worker, job)
          Honeybadger.clear!
          yield
        end
      end

      Plugin.register do
        requirement { defined?(::Faktory) }

        execution do
          ::Faktory.configure_worker do |faktory|
            faktory.worker_middleware do |chain|
              chain.prepend Middleware
            end
          end

          ::Faktory.configure_worker do |faktory|
            faktory.error_handlers << lambda do |ex, params|
              opts = {parameters: params}

              if job = params[:job]
                if (threshold = config[:'faktory.attempt_threshold'].to_i) > 0
                  retry_opt = job['retry'].to_i
                  current_retry = job['failure']['retry_count'].to_i
                  limit = [retry_opt - 1, threshold].min

                  return if current_retry < limit
                end

                opts[:component] = job['jobtype']
                opts[:action] = 'perform'
              end

              Honeybadger.notify(ex, opts)
            end
          end
        end
      end
    end
  end
end
