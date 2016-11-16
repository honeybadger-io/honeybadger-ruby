module Honeybadger
  module Rack
    # Internal: Constructs a request hash from a Rack::Request matching the
    # /v1/notices API specification.
    module RequestHash
      # Internal
      CGI_BLACKLIST = ['QUERY_STRING', 'RAW_POST_DATA', 'ORIGINAL_FULLPATH', 'REQUEST_URI'].freeze
      CGI_KEY_REGEXP = /\A[A-Z_]+\Z/

      def self.from_env(env)
        return {} unless defined?(::Rack::Request)

        hash, request = {}, ::Rack::Request.new(env)

        hash[:url] = extract_url(request)
        hash[:params] = extract_params(request)
        hash[:component] = hash[:params]['controller']
        hash[:action] = hash[:params]['action']
        hash[:session] = extract_session(request)
        hash[:cgi_data] = extract_cgi_data(request)

        hash
      end

      def self.extract_url(request)
        request.env['honeybadger.request.url'] || request.url
      rescue => e
        "Failed to access URL -- #{e}"
      end

      def self.extract_params(request)
        (request.env['action_dispatch.request.parameters'] || request.params).to_hash || {}
      rescue => e
        { error: "Failed to access params -- #{e}" }
      end

      def self.extract_session(request)
        request.session.to_hash
      rescue => e
        # Rails raises ArgumentError when `config.secret_token` is missing, and
        # ActionDispatch::Session::SessionRestoreError when the session can't be
        # restored.
        { error: "Failed to access session data -- #{e}" }
      end

      def self.extract_cgi_data(request)
        request.env.reject {|k,_| cgi_blacklist?(k) }
      end

      def self.cgi_blacklist?(key)
        return true if CGI_BLACKLIST.include?(key)
        return true unless key.match(CGI_KEY_REGEXP)

        false
      end
    end
  end
end
