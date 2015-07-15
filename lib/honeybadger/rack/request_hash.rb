module Honeybadger
  module Rack
    # Internal: Constructs a request hash from a Rack::Request matching the
    # /v1/notices API specification.
    class RequestHash < ::Hash
      # Internal
      CGI_BLACKLIST = ['QUERY_STRING', 'RAW_POST_DATA'].freeze
      CGI_KEY_REGEXP = /\A[A-Z_]+\Z/

      def initialize(request)
        self[:url] = extract_url(request)
        self[:params] = extract_params(request)
        self[:component] = self[:params]['controller']
        self[:action] = self[:params]['action']
        self[:session] = extract_session(request)
        self[:cgi_data] = extract_cgi_data(request)
      end

      private

      def extract_url(request)
        request.env['honeybadger.request.url'] || request.url
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
        request.env.reject {|k,_| cgi_blacklist?(k) }
      end

      def cgi_blacklist?(key)
        return true if CGI_BLACKLIST.include?(key)
        return true unless key.match(CGI_KEY_REGEXP)

        false
      end
    end
  end
end
