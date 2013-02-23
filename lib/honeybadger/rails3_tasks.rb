require 'honeybadger'
require File.join(File.dirname(__FILE__), 'shared_tasks')

namespace :honeybadger do
  desc "Verify your gem installation by sending a test exception to the honeybadger service"
  task :test do
    Rails.logger = if defined?(ActiveSupport::TaggedLogging)
                     ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
                   else
                     Logger.new(STDOUT)
                   end
    Rails.logger.level = Logger::INFO

    Honeybadger.configure(true) do |config|
      config.logger = Rails.logger
      config.debug = true
      config.development_environments = []
    end

    # Ensure force_ssl is disabled, otherwise we'll get a 301 when we
    # try to hit the /verify action
    Rails.configuration.middleware.delete 'Rack::SSL'

    Rake::Task['environment'].invoke

    # Suppress error logging in Rails' exception handling middleware. Rails 3.0
    # uses ActionDispatch::ShowExceptions to rescue/show exceptions, but does
    # not log anything but application trace. Rails 3.2 now falls back to
    # logging the framework trace (moved to ActionDispatch::DebugExceptions),
    # which caused cluttered output while running the test task.
    class ActionDispatch::DebugExceptions ; def logger(*args) ; @logger ||= Logger.new('/dev/null') ; end ; end
    class ActionDispatch::ShowExceptions ; def logger(*args) ; @logger ||= Logger.new('/dev/null') ; end ; end

    # Detect and disable the better_errors gem
    if defined? BetterErrors::Middleware
      puts 'Better Errors detected: temporarily disabling middleware.'
      class BetterErrors::Middleware ; def call(env) ; end ; end
    end

    require './app/controllers/application_controller'

    class HoneybadgerTestingException < RuntimeError; end

    unless Honeybadger.configuration.api_key
      puts "Honeybadger needs an API key configured! Check the README to see how to add it."
      exit
    end

    if Honeybadger.configuration.async?
      puts "Temporarily disabling asynchronous delivery"
      Honeybadger.configuration.async = nil
    end

    puts "Configuration:"
    Honeybadger.configuration.to_hash.each do |key, value|
      puts sprintf("%25s: %s", key.to_s, value.inspect.slice(0, 55))
    end

    unless defined?(ApplicationController)
      puts "No ApplicationController found"
      exit
    end

    puts 'Setting up the Controller.'
    class ApplicationController
      # This is to bypass any filters that may prevent access to the action.
      prepend_before_filter :test_honeybadger
      def test_honeybadger
        puts "Raising '#{exception_class.name}' to simulate application failure."
        raise exception_class.new, 'Testing honeybadger via "rake honeybadger:test". If you can see this, it works.'
      end

      # Ensure we actually have an action to go to.
      def verify; end

      def exception_class
        exception_name = ENV['EXCEPTION'] || "HoneybadgerTestingException"
        Object.const_get(exception_name)
      rescue
        Object.const_set(exception_name, Class.new(Exception))
      end
    end

    Rails.application.routes.draw do
      match 'verify' => 'application#verify', :as => 'verify'
    end

    puts 'Processing request.'
    env = Rack::MockRequest.env_for("/verify")

    Rails.application.call(env)
  end
end
