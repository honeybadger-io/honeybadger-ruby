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
        # for checkin config sync
        @personal_auth_token = config.get(:personal_auth_token)
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


      #
      ##### Checkin Crud methods
      #

      def get_checkin(project_id, id)
        response = Response.new(@http.get("/v2/projects/#{project_id}/check_ins/#{id}", personal_auth_headers))
        if response.success?
          return Checkin.from_remote(project_id, JSON.parse(response.body))
        else
          if response.code == 404
            return nil
          end
        end
        raise CheckinSyncError.new "Fetching Checkin failed (Code: #{response.code}) #{response.body}"
      end

      def get_checkins(project_id)
        response = Response.new(@http.get("/v2/projects/#{project_id}/check_ins", personal_auth_headers))
        if response.success?
          all_checkins = JSON.parse(response.body)["results"]
          return all_checkins.map{|cfg| Checkin.from_remote(project_id, cfg) }
        end
        raise CheckinFetchError.new "Fetching Checkins failed (Code: #{response.code}) #{response.body}"
      end
      
      def update_checkin(project_id, id, data)
        response = Response.new(@http.put("/v2/projects/#{project_id}/check_ins/#{id}", data.to_json, personal_auth_headers))
        return Checkin.from_remote(project_id, JSON.parse(response.body))
      end

      def create_checkin(project_id, data)
        response = Response.new(@http.post("/v2/projects/#{project_id}/check_ins", data.to_json, personal_auth_headers))
        if response.success?
          return Checkin.from_remote(project_id, JSON.parse(response.body))
        end
        raise CheckinFetchError.new "Saving Checkin failed (Code: #{response.code}) #{response.body}"
      end

      def delete_checkin(checkin, access_token)
        response = Response.new(@http.delete("/v2/projects/#{checkin.project_id}/check_ins/#{checkin.id}", personal_auth_headers))
        if response.success?
          return true
        end
        raise CheckinFetchError.new "Deleting Checkin failed (Code: #{response.code}) #{response.body}"
      end

      private

      def personal_auth_headers
        {"Authorization" => "#{@personal_auth_token}:"}
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
