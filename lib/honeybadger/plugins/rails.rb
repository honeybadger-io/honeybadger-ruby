require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    module Rails
      module ExceptionsCatcher
        def self.included(base)
          base.send(:alias_method, :render_exception_without_honeybadger, :render_exception)
          base.send(:alias_method, :render_exception, :render_exception_with_honeybadger)
        end

        def render_exception_with_honeybadger(env, exception)
          env['honeybadger.exception'] = exception
          render_exception_without_honeybadger(env,exception)
        end
      end

      Plugin.register do
        requirement { defined?(::Rails) }

        execution do
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
