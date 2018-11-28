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
              chain.prepend Middleware
            end
          end

          if defined?(::Sidekiq::VERSION) && ::Sidekiq::VERSION > '3'
            ::Sidekiq.configure_server do |sidekiq|
              sidekiq.error_handlers << lambda {|ex, params|
                job = params[:job] || params
                retry_count = job['retry_count'.freeze].to_i
                retry_opt = job['retry'.freeze]
                max_retries = if retry_opt.is_a?(Integer)
                  [retry_opt - 1, config[:'sidekiq.attempt_threshold'].to_i].min
                else
                  config[:'sidekiq.attempt_threshold'].to_i
                end

                return if retry_opt && retry_count < max_retries
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
