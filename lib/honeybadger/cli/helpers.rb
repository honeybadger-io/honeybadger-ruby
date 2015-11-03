require 'logger'

module Honeybadger
  module CLI
    module Helpers
      def rails?(opts = {})
        @rails ||= load_rails(opts)
      end

      def load_rails(opts = {})
        begin
          require 'honeybadger/init/rails'
          if ::Rails::VERSION::MAJOR >= 3
            say("Detected Rails #{::Rails::VERSION::STRING}") if opts[:verbose]
          else
            say("Error: Rails #{::Rails::VERSION::STRING} is unsupported.", :red)
            exit(1)
          end
        rescue LoadError
          say("Rails was not detected, loading standalone.") if opts[:verbose]
          return @rails = false
        rescue StandardError => e
          say("Error while detecting Rails: #{e.class} -- #{e.message}", :red)
          exit(1)
        end

        begin
          require File.expand_path('config/application')
        rescue LoadError
          say('Error: could not load Rails application. Please ensure you run this command from your project root.', :red)
          exit(1)
        end

        @rails = true
      end

      def load_rails_env(opts = {})
        return false unless rails?(opts)

        puts('Loading Rails environment') if opts[:verbose]
        ::Rails.application.require_environment!

        true
      end

      def rails_framework_opts
        return {} unless defined?(::Rails)

        {
          :root           => ::Rails.root,
          :env            => ::Rails.env,
          :'config.path'  => ::Rails.root.join('config', 'honeybadger.yml'),
          :framework      => :rails
        }
      end

      def test_exception_class
        exception_name = ENV['EXCEPTION'] || 'HoneybadgerTestingException'
        Object.const_get(exception_name)
      rescue
        Object.const_set(exception_name, Class.new(Exception))
      end

      def send_test(verbose = true)
        if defined?(::Rails)
          rails_test(verbose)
        else
          standalone_test
        end
      end

      def standalone_test
        Honeybadger.notify(test_exception_class.new('Testing honeybadger via "honeybadger test". If you can see this, it works.'))
      end

      def rails_test(verbose = true)
        if verbose
          ::Rails.logger = if defined?(::ActiveSupport::TaggedLogging)
                             ::ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
                           else
                             Logger.new(STDOUT)
                           end
          ::Rails.logger.level = Logger::INFO
        end

        # Suppress error logging in Rails' exception handling middleware. Rails 3.0
        # uses ActionDispatch::ShowExceptions to rescue/show exceptions, but does
        # not log anything but application trace. Rails 3.2 now falls back to
        # logging the framework trace (moved to ActionDispatch::DebugExceptions),
        # which caused cluttered output while running the test task.
        defined?(::ActionDispatch::DebugExceptions) and
          ::ActionDispatch::DebugExceptions.class_eval { def logger(*args) ; @logger ||= Logger.new('/dev/null') ; end }
        defined?(::ActionDispatch::ShowExceptions) and
        ::ActionDispatch::ShowExceptions.class_eval { def logger(*args) ; @logger ||= Logger.new('/dev/null') ; end }

        # Detect and disable the better_errors gem
        if defined?(::BetterErrors::Middleware)
          say('Better Errors detected: temporarily disabling middleware.', :yellow)
          ::BetterErrors::Middleware.class_eval { def call(env) @app.call(env); end }
        end

        begin
          require './app/controllers/application_controller'
        rescue LoadError
          nil
        end

        unless defined?(::ApplicationController)
          say('Error: No ApplicationController found.', :red)
          return false
        end

        say('Setting up the Controller.')
        eval(<<-CONTROLLER)
        class Honeybadger::TestController < ApplicationController
          # This is to bypass any filters that may prevent access to the action.
          if respond_to?(:prepend_before_action)
            prepend_before_action :test_honeybadger
          else
            prepend_before_filter :test_honeybadger
          end

          def test_honeybadger
            puts "Raising '#{test_exception_class.name}' to simulate application failure."
            raise #{test_exception_class}.new, 'Testing honeybadger via "honeybadger test", it works.'
          end

          # Ensure we actually have an action to go to.
          def verify; end
        end
        CONTROLLER

        ::Rails.application.routes.tap do |r|
          # RouteSet#disable_clear_and_finalize prevents existing routes from
          # being cleared. We'll set it back to the original value when we're
          # done so not to mess with Rails state.
          d = r.disable_clear_and_finalize
          begin
            r.disable_clear_and_finalize = true
            r.clear!
            r.draw do
              match 'verify' => 'honeybadger/test#verify', :as => 'verify', :via => :get
            end
            ::Rails.application.routes_reloader.paths.each{ |path| load(path) }
            ::ActiveSupport.on_load(:action_controller) { r.finalize! }
          ensure
            r.disable_clear_and_finalize = d
          end
        end

        say('Processing request.')

        ssl = defined?(::Rails.configuration.force_ssl) && ::Rails.configuration.force_ssl
        env = ::Rack::MockRequest.env_for("http#{ ssl ? 's' : nil }://www.example.com/verify", 'REMOTE_ADDR' => '127.0.0.1')

        ::Rails.application.call(env)
      end
    end
  end
end
