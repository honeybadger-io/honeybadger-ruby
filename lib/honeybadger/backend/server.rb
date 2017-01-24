require 'net/http'
require 'json'
require 'zlib'
require 'openssl'

require 'honeybadger/backend/base'
require 'honeybadger/util/http'

module Honeybadger
  module Backend
    class Server < Base
      ENDPOINTS = {
        notices: '/v1/notices'.freeze,
        deploys: '/v1/deploys'.freeze
      }.freeze

      HTTP_ERRORS = Util::HTTP::ERRORS

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
        Response.new(:error, nil, "HTTP Error: #{e.class}")
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
