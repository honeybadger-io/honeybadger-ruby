module Honeybadger
  module Integrations
    module Sidekiq
      class Middleware
        def call(worker, msg, queue)
          begin
            yield
          ensure
            Honeybadger.context.clear!
          end
        end
      end
    end
  end

  Dependency.register do
    requirement { defined?(::Sidekiq) }

    injection do
      ::Sidekiq.configure_server do |config|
        config.server_middleware do |chain|
          chain.add Integrations::Sidekiq::Middleware
        end
      end
    end
  end

  Dependency.register do
    requirement { defined?(::Sidekiq::VERSION) && ::Sidekiq::VERSION > '3' }

    injection do
      ::Sidekiq.configure_server do |config|
        config.error_handlers << Proc.new {|ex,context| Honeybadger.notify_or_ignore(ex, :parameters => context) }
      end
    end
  end
end
