require "forwardable"

module Honeybadger
  module Rack
    # Middleware for Rack applications. Adds an error ID to the Rack response
    # when an error has occurred.
    class UserInformer
      extend Forwardable

      def initialize(app, agent = nil)
        @app = app
        @agent = agent.is_a?(Agent) && agent
      end

      def replacement(with)
        config[:"user_informer.info"].gsub(/\{\{\s*error_id\s*\}\}/, with.to_s)
      end

      def call(env)
        status, headers, body = @app.call(env)
        if env["honeybadger.error_id"]
          new_body = []
          replace = replacement(env["honeybadger.error_id"])
          body.each do |chunk|
            new_body << chunk.gsub("<!-- HONEYBADGER ERROR -->", replace)
          end
          body.close if body.respond_to?(:close)
          headers["Content-Length"] = new_body.reduce(0) { |a, e| a + e.bytesize }.to_s
          body = new_body
        end
        [status, headers, body]
      end

      private

      def_delegator :agent, :config
      def_delegator :config, :logger

      def agent
        @agent || Honeybadger::Agent.instance
      end
    end
  end
end
