require 'delayed_job'
require 'honeybadger'

module Honeybadger
  module Plugins
    module DelayedJob
      class Plugin < ::Delayed::Plugin
        callbacks do |lifecycle|
          lifecycle.around(:invoke_job) do |job, &block|
            begin
              ::Honeybadger.context(
                :job_id        => job.id,
                :handler       => job.handler,
                :last_error    => job.last_error,
                :attempts      => job.attempts,
                :queue         => job.queue
              )
              ::Honeybadger::Trace.instrument("#{job.payload_object.class}#perform", {source: 'delayed_job', jid: job.id, class: job.payload_object.class.name}) do
                block.call(job)
              end
            rescue Exception => error
              component = job.payload_object.object.is_a?(Class) ? job.payload_object.object.name : job.payload_object.object.class.name rescue nil

              ::Honeybadger.notify_or_ignore(
                :component     => component,
                :action        => job.payload_object.method_name.to_s,
                :error_class   => error.class.name,
                :error_message => "#{ error.class.name }: #{ error.message }",
                :backtrace     => error.backtrace
              ) if job.attempts.to_i >= ::Honeybadger::Agent.config[:'delayed_job.attempt_threshold'].to_i
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
