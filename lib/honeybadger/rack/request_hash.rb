require 'rack/request'

module Honeybadger
  module Rack
    # Internal: Constructs a request hash from a Rack::Request matching the
    # /v1/notices API specification.
    class RequestHash < ::Hash
      def initialize(request)
        unless request.kind_of?(::Rack::Request)
          raise ArgumentError, "Expected Rack::Request, got #{request.class.name}"
        end

        self[:url] = extract_url(request)
        self[:params] = extract_params(request)
        self[:component] = self[:params]['controller']
        self[:action] = self[:params]['action']
        self[:session] = extract_session(request)
        self[:cgi_data] = extract_cgi_data(request)
      end

      private

      def extract_url(request)
        request.url
      rescue => e
        # TODO: Log these errors
        "Error: #{e.message}"
      end

      def extract_params(request)
        (request.env['action_dispatch.request.parameters'] || request.params).to_hash || {}
      rescue => e
        { error: "Failed to access params -- #{e.message}" }
      end

      def extract_session(request)
        request.session.to_hash
      rescue => e
        # Rails raises ArgumentError when `config.secret_token` is missing, and
        # ActionDispatch::Session::SessionRestoreError when the session can't be
        # restored.
        { error: "Failed to access session data -- #{e.message}" }
      end

      def extract_cgi_data(request)
        request.env.reject {|k,_| k == 'QUERY_STRING' || !k.match(/\A[A-Z_]+\Z/) }
      end
    end
  end
end
