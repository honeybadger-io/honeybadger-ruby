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

      # Get checkin by id
      # @example
      #   backend.get_checkin('1234', 'ajdja")
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @returns [Checkin] or nil if checkin is not found
      # @raises CheckinSyncError on error

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

      # Get checkins by project
      # @example
      #   backend.get_checkins('1234')
      #
      # @param [String] project_id The unique project id
      # @returns [Array<Checkin>] All checkins for this project
      # @raises CheckinSyncError on error
      def get_checkins(project_id)
        response = Response.new(@http.get("/v2/projects/#{project_id}/check_ins", personal_auth_headers))
        if response.success?
          all_checkins = JSON.parse(response.body)["results"]
          return all_checkins.map{|cfg| Checkin.from_remote(project_id, cfg) }
        end
        raise CheckinSyncError.new "Fetching Checkins failed (Code: #{response.code}) #{response.body}"
      end

      # Create checkin on project
      # @example
      #   backend.create_checkin('1234', checkin)
      #
      # @param [String] project_id The unique project id
      # @param [Checkin] data A Checkin object encapsulating the config
      # @returns [Checkin] A checkin object containing the id
      # @raises CheckinSyncError on error
      def create_checkin(project_id, data)
        response = Response.new(@http.post("/v2/projects/#{project_id}/check_ins", data.to_json, personal_auth_headers))
        if response.success?
          return Checkin.from_remote(project_id, JSON.parse(response.body))
        end
        raise CheckinSyncError.new "Creating Checkin failed (Code: #{response.code}) #{response.body}"
      end

      # Update checkin on project
      # @example
      #   backend.update_checkin('1234', 'eajaj', checkin)
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @param [Checkin] data A Checkin object encapsulating the config
      # @returns [Checkin] updated Checkin object
      # @raises CheckinSyncError on error
      def update_checkin(project_id, id, data)
        response = Response.new(@http.put("/v2/projects/#{project_id}/check_ins/#{id}", data.to_json, personal_auth_headers))
        if response.success?
          return Checkin.from_remote(project_id, JSON.parse(response.body))
        end
        raise CheckinSyncError.new "Updating Checkin failed (Code: #{response.code}) #{response.body}"
      end

      # Delete checkin
      # @example
      #   backend.delete_checkin('1234', 'eajaj')
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @returns [Boolean] true if deletion was successful
      # @raises CheckinSyncError on error
      def delete_checkin(project_id, id)
        response = Response.new(@http.delete("/v2/projects/#{project_id}/check_ins/#{id}", personal_auth_headers))
        if response.success?
          return true
        end
        raise CheckinSyncError.new "Deleting Checkin failed (Code: #{response.code}) #{response.body}"
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
