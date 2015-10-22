require 'honeybadger/plugin'
require 'honeybadger'

module Honeybadger
  module Plugins
    module Sidekiq
      class Middleware
        def call(worker, msg, queue)
          Honeybadger.context.clear!
          klass = msg['wrapped'] || msg['class']
          Honeybadger::Trace.instrument("#{klass}#perform", { :source => 'sidekiq', :jid => msg['jid'], :class => klass }) do
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
                opts = {parameters: params}
                opts[:component] = params['wrapped'] || params['class'] if config[:'sidekiq.use_component']
                Honeybadger.notify_or_ignore(ex, opts)
              }
            end
          end
        end
      end
    end
  end
end
