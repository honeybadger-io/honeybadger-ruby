module Honeybadger
  module Rails
    module Middleware
      module ExceptionsCatcher
        def self.included(base)
          base.send(:alias_method_chain,:render_exception,:honeybadger)
        end

        def skip_user_agent?(env)
          user_agent = env["HTTP_USER_AGENT"]
          ::Honeybadger.configuration.ignore_user_agent.flatten.any? { |ua| ua === user_agent }
        rescue
          false
        end

        def render_exception_with_honeybadger(env,exception)
          controller = env['action_controller.instance']
          env['honeybadger.error_id'] = Honeybadger.
            notify_or_ignore(exception,
                   (controller.respond_to?(:honeybadger_request_data) ? controller.honeybadger_request_data : {:rack_env => env})) unless skip_user_agent?(env)
          if defined?(controller.rescue_action_in_public_without_honeybadger)
            controller.rescue_action_in_public_without_honeybadger(exception)
          end
          render_exception_without_honeybadger(env,exception)
        end
      end
    end
  end
end
