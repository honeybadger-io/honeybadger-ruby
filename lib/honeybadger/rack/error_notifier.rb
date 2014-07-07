module Honeybadger
  module Rack
    # Middleware for Rack applications. Any errors raised by the upstream
    # application will be delivered to Honeybadger and re-raised.
    #
    # Synopsis:
    #
    #   require 'rack'
    #   require 'honeybadger'
    #
    #   Honeybadger.configure do |config|
    #     config.api_key = 'my_api_key'
    #   end
    #
    #   app = Rack::Builder.app do
    #     run lambda { |env| raise "Rack down" }
    #   end
    #
    #   use Honeybadger::Rack::ErrorNotifier
    #   run app
    #
    # Use a standard Honeybadger.configure call to configure your api key.
    class ErrorNotifier
      def initialize(app)
        @app = app
        Honeybadger.configuration.framework = "Rack: #{::Rack.release}"
      end

      def ignored_user_agent?(env)
        true if Honeybadger.
          configuration.
          ignore_user_agent.
          flatten.
          any? { |ua| ua === env['HTTP_USER_AGENT'] }
      end

      def notify_honeybadger(exception,env)
        Honeybadger.notify_or_ignore(exception, :rack_env => env) unless ignored_user_agent?(env)
      end

      def call(env)
        begin
          response = @app.call(env)
        rescue Exception => raised
          env['honeybadger.error_id'] = notify_honeybadger(raised, env)
          raise
        end

        framework_exception = env['rack.exception'] || env['sinatra.error']
        if framework_exception
          env['honeybadger.error_id'] = notify_honeybadger(framework_exception, env)
        end

        response
      ensure
        Honeybadger.context.clear!
      end
    end
  end
end
