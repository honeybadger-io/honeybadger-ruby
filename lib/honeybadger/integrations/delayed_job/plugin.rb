module Honeybadger
  module Integrations
    module DelayedJob
      class Plugin < ::Delayed::Plugins::Plugin
        callbacks do |lifecycle|
          lifecycle.around(:invoke_job) do |job, *args, &block|
            begin
              block.call(job, *args)
            rescue Exception => error
              ::Honeybadger.notify_or_ignore(
                :error_class   => error.class.name,
                :error_message => "#{ error.class.name }: #{ error.message }",
                :backtrace     => error.backtrace,
                  :context       => {
                  :job_id        => job.id,
                  :handler       => job.handler,
                  :last_error    => job.last_error,
                  :attempts      => job.attempts,
                  :queue         => job.queue
                }
              )
              raise error
            ensure
              ::Honeybadger.context.clear!
            end
          end
        end
      end
    end
  end
end
