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

      CHECK_IN_ENDPOINT = '/v1/check_in'.freeze


      HTTP_ERRORS = Util::HTTP::ERRORS

      def initialize(config)
        @http = Util::HTTP.new(config)
        super
      end

      # Post payload to endpoint for feature.
      #
      # @param [Symbol] feature The feature which is being notified.
      # @param [#to_json] payload The JSON payload to send.
      #
      # @return [Response]
      def notify(feature, payload)
        ENDPOINTS[feature] or raise(BackendError, "Unknown feature: #{feature}")
        Response.new(@http.post(ENDPOINTS[feature], payload, payload_headers(payload)))
      rescue *HTTP_ERRORS => e
        Response.new(:error, nil, "HTTP Error: #{e.class}")
      end

      # Does a check in using the input id.
      #
      # @param [String] id The unique check_in id.
      #
      # @return [Response]
      def check_in(id)
        Response.new(@http.get("#{CHECK_IN_ENDPOINT}/#{id}"))
      rescue *HTTP_ERRORS => e
        Response.new(:error, nil, "HTTP Error: #{e.class}")
      end

      # Sync checkin configs
      # @example
      #   backend.sync_checkins([{project_id: "11222", slug: "some slug", schedule_type: "simple", report_period: "1 hour"}])
      #
      # @param [Array] checkins The checkin configurations that should be synced
      def sync_checkins(checkins)
        validate_checkins(checkins)
        added = sync_existing_checkins(checkins)
        removed = sync_removed_checkins(checkins)

        return (added + removed).uniq

        raise NotImplementedError, 'must define #sync_checkins on subclass'
      end

      private

      def sync_existing_checkins(checkins)
        return [] if checkins.nil? || checkins.empty?
        checkins
      end

      def sync_removed_checkins(checkins)
        return [] if checkins.nil? || checkins.empty?
        checkins
      end

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
