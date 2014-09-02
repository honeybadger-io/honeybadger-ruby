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
          ::Sidekiq.configure_server do |config|
            config.server_middleware do |chain|
              chain.add Middleware
            end
          end

          if defined?(::Sidekiq::VERSION) && ::Sidekiq::VERSION > '3'
            ::Sidekiq.configure_server do |config|
              config.error_handlers << Proc.new {|ex,context| Honeybadger.notify_or_ignore(ex, parameters: context) }
            end
          end
        end
      end
    end
  end
end
