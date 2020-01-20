require 'honeybadger/plugin'
require 'honeybadger/ruby'

module Honeybadger
  module Plugins
    module Faktory
      class Middleware
        def call(worker, job)
          Honeybadger.clear!
          yield
        end
      end

      Plugin.register do
        requirement { defined?(::Faktory) }

        execution do
          ::Faktory.configure_worker do |faktory|
            faktory.worker_middleware do |chain|
              chain.prepend Middleware
            end
          end

          ::Faktory.configure_worker do |faktory|
            faktory.error_handlers << lambda do |ex, params|
              opts = {parameters: params}
              Honeybadger.notify(ex, opts)
            end
          end
        end
      end
    end
  end
end
