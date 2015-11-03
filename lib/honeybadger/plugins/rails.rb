require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    module Rails
      module ExceptionsCatcher
        def self.included(base)
          base.send(:alias_method, :render_exception_without_honeybadger, :render_exception)
          base.send(:alias_method, :render_exception, :render_exception_with_honeybadger)
        end

        # Internal: Adds additional Honeybadger info to Request env when an
        # exception is rendered in Rails' middleware.
        #
        # arg       - The Rack env Hash in Rails 3.0-4.2. After Rails 5 arg is
        #             an ActionDispatch::Request.
        # exception - The Exception which was rescued.
        #
        # Returns the super value of the middleware's #render_exception()
        # method.
        def render_exception_with_honeybadger(arg, exception)
          if arg.kind_of?(::ActionDispatch::Request)
            request = arg
            env = request.env
          else
            request = ::Rack::Request.new(arg)
            env = arg
          end

          env['honeybadger.exception'] = exception
          env['honeybadger.request.url'] = request.url rescue nil

          render_exception_without_honeybadger(arg, exception)
        end
      end

      module ControllerMethods
        def honeybadger_request_data
          warn('#honeybadger_request_data has been deprecated and has no effect.')
          {}
        end

        def notify_honeybadger(*args, &block)
          warn('#notify_honeybadger has been deprecated; please use `Honeybadger.notify`.')
          Honeybadger.notify(*args, &block)
        end

        def notify_honeybadger_or_ignore(*args, &block)
          warn('#notify_honeybadger_or_ignore has been deprecated; please use `Honeybadger.notify`.')
          Honeybadger.notify(*args, &block)
        end
      end

      Plugin.register :rails_controller_methods do
        requirement { defined?(::Rails) }

        execution do
          ActiveSupport.on_load(:action_controller) do
            # Lazily load action_controller methods
            include ::Honeybadger::Plugins::Rails::ControllerMethods
          end
        end
      end

      Plugin.register :rails_exceptions_catcher do
        requirement { defined?(::Rails) }

        execution do
          require 'rack/request'
          if defined?(::ActionDispatch::DebugExceptions)
            # Rails 3.2.x+
            ::ActionDispatch::DebugExceptions.send(:include, ExceptionsCatcher)
          elsif defined?(::ActionDispatch::ShowExceptions)
            # Rails 3.0.x and 3.1.x
            ::ActionDispatch::ShowExceptions.send(:include, ExceptionsCatcher)
          end
        end
      end
    end
  end
end
