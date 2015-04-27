require 'honeybadger/plugin'
require 'honeybadger'

module Honeybadger
  module Plugins
    module Sidekiq
      class Middleware
        def call(worker, msg, queue)
          Honeybadger.context.clear!
          Honeybadger::Trace.instrument("#{msg['class']}#perform", { :source => 'sidekiq', :jid => msg['jid'], :class => msg['class'] }) do
            yield
          end
        end
      end

      Plugin.register do
        requirement { defined?(::Sidekiq) }

        execution do
          ::Sidekiq.configure_server do |sidekiq|
            sidekiq.server_middleware do |chain|
              chain.add Middleware
            end
          end

          if defined?(::Sidekiq::VERSION) && ::Sidekiq::VERSION > '3'
            ::Sidekiq.configure_server do |sidekiq|
              sidekiq.error_handlers << lambda {|ex, params|
                return if params['retry'] && params['retry_count'].to_i < config[:'sidekiq.attempt_threshold'].to_i
                Honeybadger.notify_or_ignore(ex, parameters: params)
              }
            end
          end
        end
      end
    end
  end
end
