require "honeybadger/ruby"

module Honeybadger
  module Rack
    # @api private
    #
    # Copies the request ID assigned by ActionDispatch::RequestId into the
    # Honeybadger context. Must sit after ActionDispatch::RequestId in the
    # middleware stack.
    #
    # No ensure/cleanup here: ErrorNotifier owns the request lifecycle and
    # clears state after the stack unwinds. Clearing here would nil the ID
    # before ErrorNotifier builds the notice on exception.
    class RequestId
      def initialize(app, agent = nil)
        @app = app
        @agent = agent if agent.is_a?(Agent)
      end

      def call(env)
        request_id = env["action_dispatch.request_id"]
        (@agent || Honeybadger::Agent.instance).set_request_id(request_id) if request_id
        @app.call(env)
      end
    end
  end
end
