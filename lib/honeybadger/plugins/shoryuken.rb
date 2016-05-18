require 'honeybadger/plugin'
require 'honeybadger'

module Honeybadger
  module Plugins
    module Shoryuken
      class Middleware
        def call(worker, queue, sqs_msg, body)
          if sqs_msg.is_a?(Array)
            yield
            return
          end

          klass = worker.class.name
          Honeybadger.flush do
            Honeybadger::Trace.instrument("#{klass}#perform", { :source => 'shoryuken'.freeze, :queue => sqs_msg.queue_name.freeze, :message_id => sqs_msg.data.message_id.freeze, :class => klass }) do
              begin
                yield
              rescue => e
                receive_count = sqs_msg.attributes['ApproximateReceiveCount'.freeze]
                if receive_count && ::Honeybadger::Agent.config[:'shoryuken.attempt_threshold'].to_i <= receive_count.to_i
                  Honeybadger.notify(e, parameters: body)
                end
                raise e
              end
            end
          end
        ensure
          Honeybadger.context.clear!
        end
      end

      Plugin.register do
        requirement { defined?(::Shoryuken) }

        execution do
          ::Shoryuken.configure_server do |config|
            config.server_middleware do |chain|
              chain.add Middleware
            end
          end
        end
      end
    end
  end
end
