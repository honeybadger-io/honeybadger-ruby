module Honeybadger
  module Integrations
    module Sidekiq
      class Middleware
        def call(worker, msg, queue)
          Honeybadger.context.clear!
          yield
        end
      end
    end
  end
end

if defined?(::Sidekiq)
  ::Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Honeybadger::Integrations::Sidekiq::Middleware
    end
  end
end

if defined?(::Sidekiq::VERSION) && ::Sidekiq::VERSION > '3'
  ::Sidekiq.configure_server do |config|
    config.error_handlers << Proc.new {|ex,context| Honeybadger.notify_or_ignore(ex, :parameters => context) }
  end
end
