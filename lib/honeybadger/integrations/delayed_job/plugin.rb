module Honeybadger
  module Integrations
    module DelayedJob
      class Plugin < ::Delayed::Plugin
        callbacks do |lifecycle|
          lifecycle.around(:invoke_job) do |job, &block|
            begin
              Honeybadger::Monitor::Trace.instrument("#{job.payload_object.class}#perform", { :source => 'delayed_job', :jid => job.id, :class => job.payload_object.class.name }) do
                block.call(job)
              end
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
