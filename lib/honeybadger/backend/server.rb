module Honeybadger
  module Backend
    class Server < Base
      ENDPOINTS = {
        ping: '/v1/ping'.freeze,
        notices: '/v1/notices'.freeze,
        deploys: '/v1/deploys'.freeze
      }.freeze

      HTTP_ERRORS = [Timeout::Error,
                     Errno::EINVAL,
                     Errno::ECONNRESET,
                     Errno::ECONNREFUSED,
                     Errno::ENETUNREACH,
                     EOFError,
                     Net::HTTPBadResponse,
                     Net::HTTPHeaderSyntaxError,
                     Net::ProtocolError,
                     OpenSSL::SSL::SSLError,
                     SocketError].freeze

      def initialize(config)
        @http = Util::HTTP.new(config)
        super
      end

      # Internal: Post payload to endpoint for feature.
      #
      # feature - The feature which is being notified.
      # payload - The payload to send, responding to `#to_json`.
      #
      # Returns Response.
      def notify(feature, payload)
        ENDPOINTS[feature] or raise(BackendError, "Unknown feature: #{feature}")
        Response.new(@http.post(ENDPOINTS[feature], payload, payload_headers(payload)))
      rescue *HTTP_ERRORS => e
        Response.new(:error, nil, "HTTP Error: #{e.class}").tap do |response|
          error { sprintf('http error class=%s message=%s', e.class, e.message.dump) }
        end
      end

      private

      # Internal: Construct headers for supported payloads.
      #
      # payload - The payload object.
      #
      # Returns Hash headers if supported, otherwise nil.
      def payload_headers(payload)
        if payload.respond_to?(:api_key) && payload.api_key
          {
            'X-API-Key' => payload.api_key
          }
        end
      end
    end
  end
end
