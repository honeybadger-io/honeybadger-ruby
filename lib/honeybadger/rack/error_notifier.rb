require 'rack/request'
require 'honeybadger'
require 'forwardable'

module Honeybadger
  module Rack
    # Public: Middleware for Rack applications. Any errors raised by the upstream
    # application will be delivered to Honeybadger and re-raised.
    #
    # Examples:
    #
    #   require 'honeybadger/rack/error_notifier'
    #
    #   app = Rack::Builder.app do
    #     run lambda { |env| raise "Rack down" }
    #   end
    #
    #   use Honeybadger::Rack::ErrorNotifier
    #
    #   run app
    class ErrorNotifier
      extend Forwardable

      def initialize(app, config)
        @app = app
        @config = config
      end

      def call(env)
        config.with_request(::Rack::Request.new(env)) do
          begin
            env['honeybadger.config'] = config
            response = @app.call(env)
          rescue Exception => raised
            env['honeybadger.error_id'] = notify_honeybadger(raised, env)
            raise
          end

          framework_exception = framework_exception(env)
          if framework_exception
            env['honeybadger.error_id'] = notify_honeybadger(framework_exception, env)
          end

          response
        end
      ensure
        Honeybadger.context.clear!
      end

      private

      attr_reader :config
      def_delegator :@config, :logger

      def ignored_user_agent?(env)
        true if config[:'exceptions.ignored_user_agents'].
          flatten.
          any? { |ua| ua === env['HTTP_USER_AGENT'] }
      end

      def notify_honeybadger(exception, env)
        return if ignored_user_agent?(env)
        Honeybadger.notify_or_ignore(exception)
      end

      def framework_exception(env)
        env['action_dispatch.exception'] || env['rack.exception'] ||
          env['sinatra.error'] || env['honeybadger.exception']
      end
    end
  end
end
