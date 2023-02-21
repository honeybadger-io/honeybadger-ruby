require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    # @api private
    Plugin.register :auto_logging do
      requirement { config[:'auto_logging.enabled'] }

      execution do
        next if @subscriber

        @subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |name, started, finished, unique_id, payload|
          Honeybadger::Logger.info(payload.slice(:controller, :action, :params, :format,
            :method, :path, :status, :view_runtime, :db_runtime).merge({ event: name }))
        end
      end
    end
  end
end
