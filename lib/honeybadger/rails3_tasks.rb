require 'honeybadger'
require File.join(File.dirname(__FILE__), 'shared_tasks')

namespace :honeybadger do
  desc "Verify your gem installation by sending a test exception to the honeybadger service"
  task :test => :environment do
    Rails.logger = if defined?(ActiveSupport::TaggedLogging)
                     ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
                   else
                     Logger.new(STDOUT)
                   end
    Rails.logger.level = Logger::DEBUG

    Honeybadger.configure(true) do |config|
      config.logger = Rails.logger
    end

    # Suppress error logging in Rails' exception handling middleware. Rails 3.0
    # uses ActionDispatch::ShowExceptions to rescue/show exceptions, but does
    # not log anything but application trace. Rails 3.2 now falls back to
    # logging the framework trace (moved to ActionDispatch::DebugExceptions),
    # which caused cluttered output while running the test task.
    class ActionDispatch::DebugExceptions ; def logger(*args) ; @logger ||= Logger.new('/dev/null') ; end ; end
    class ActionDispatch::ShowExceptions ; def logger(*args) ; @logger ||= Logger.new('/dev/null') ; end ; end

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

    Honeybadger.configuration.development_environments = []

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
