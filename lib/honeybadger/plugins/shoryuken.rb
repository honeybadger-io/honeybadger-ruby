require 'honeybadger/plugin'
require 'honeybadger/ruby'

module Honeybadger
  module Plugins
    module Shoryuken
      class Middleware
        def call(worker, queue, sqs_msg, body)
          if sqs_msg.is_a?(Array)
            yield
            return
          end

          Honeybadger.flush do
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
