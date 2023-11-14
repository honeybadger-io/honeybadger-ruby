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
        # for check_in config sync
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
      ##### CheckIn Crud methods
      #

      # Get check_in by id
      # @example
      #   backend.get_check_in('1234', 'ajdja")
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @returns [CheckIn] or nil if check_in is not found
      # @raises CheckInSyncError on error

      def get_check_in(project_id, id)
        response = Response.new(@http.get("/v2/projects/#{project_id}/check_ins/#{id}", personal_auth_headers))
        if response.success?
          return CheckIn.from_remote(project_id, JSON.parse(response.body))
        else
          if response.code == 404
            return nil
          end
        end
        raise CheckInSyncError.new "Fetching CheckIn failed (Code: #{response.code}) #{response.body}"
      end

      # Get check_ins by project
      # @example
      #   backend.get_check_ins('1234')
      #
      # @param [String] project_id The unique project id
      # @returns [Array<CheckIn>] All checkins for this project
      # @raises CheckInSyncError on error
      def get_check_ins(project_id)
        response = Response.new(@http.get("/v2/projects/#{project_id}/check_ins", personal_auth_headers))
        if response.success?
          all_check_ins = JSON.parse(response.body)["results"]
          return all_check_ins.map{|cfg| CheckIn.from_remote(project_id, cfg) }
        end
        raise CheckInSyncError.new "Fetching CheckIns failed (Code: #{response.code}) #{response.body}"
      end

      # Create check_in on project
      # @example
      #   backend.create_check_in('1234', check_in)
      #
      # @param [String] project_id The unique project id
      # @param [CheckIn] check_in_config A CheckIn object encapsulating the config
      # @returns [CheckIn] A CheckIn object additionally containing the id
      # @raises CheckInSyncError on error
      def create_check_in(project_id, check_in_config)
        response = Response.new(@http.post("/v2/projects/#{project_id}/check_ins", check_in_config.to_json, personal_auth_headers))
        if response.success?
          return CheckIn.from_remote(project_id, JSON.parse(response.body))
        end
        raise CheckInSyncError.new "Creating CheckIn failed (Code: #{response.code}) #{response.body}"
      end

      # Update check_in on project
      # @example
      #   backend.update_check_in('1234', 'eajaj', check_in)
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @param [CheckIn] check_in_config A CheckIn object encapsulating the config
      # @returns [CheckIn] updated CheckIn object
      # @raises CheckInSyncError on error
      def update_check_in(project_id, id, check_in_config)
        response = Response.new(@http.put("/v2/projects/#{project_id}/check_ins/#{id}", check_in_config.to_json, personal_auth_headers))
        if response.success?
          return CheckIn.from_remote(project_id, JSON.parse(response.body))
        end
        raise CheckInSyncError.new "Updating CheckIn failed (Code: #{response.code}) #{response.body}"
      end

      # Delete check_in
      # @example
      #   backend.delete_check_in('1234', 'eajaj')
      #
      # @param [String] project_id The unique project id
      # @param [String] id The unique check_in id
      # @returns [Boolean] true if deletion was successful
      # @raises CheckInSyncError on error
      def delete_check_in(project_id, id)
        response = Response.new(@http.delete("/v2/projects/#{project_id}/check_ins/#{id}", personal_auth_headers))
        if response.success?
          return true
        end
        raise CheckInSyncError.new "Deleting CheckIn failed (Code: #{response.code}) #{response.body}"
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
