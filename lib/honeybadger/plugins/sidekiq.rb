require 'honeybadger/plugin'
require 'honeybadger/ruby'

module Honeybadger
  module Plugins
    module Sidekiq
      class Middleware
        def call(worker, msg, queue)
          Honeybadger.context.clear!
          yield
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
                job = params[:job] || params
                return if job['retry'.freeze] && job['retry_count'.freeze].to_i < config[:'sidekiq.attempt_threshold'].to_i
                opts = {parameters: params}
                opts[:component] = job['wrapped'.freeze] || job['class'.freeze] if config[:'sidekiq.use_component']
                Honeybadger.notify(ex, opts)
              }
            end
          end
        end
      end
    end
  end
end
