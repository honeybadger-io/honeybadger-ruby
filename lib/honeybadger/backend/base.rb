require 'forwardable'
require 'net/http'
require 'json'

require 'honeybadger/logging'

module Honeybadger
  module Backend
    class Response
      NOT_BLANK = /\S/

      attr_reader :code, :body, :message, :error

      # Public: Initializes the Response instance.
      #
      # response - With 1 argument Net::HTTPResponse, the code, body, and
      #            message will be determined automatically. (optional)
      # code      - The Integer status code. May also be :error for requests which
      #             failed to reach the server.
      # body      - The String body of the response.
      # message   - The String message returned by the server (or set by the
      #             backend in the case of an :error code).
      #
      # Returns nothing
      def initialize(*args)
        if (response = args.first).kind_of?(Net::HTTPResponse)
          @code, @body, @message = response.code.to_i, response.body.to_s, response.message
        else
          @code, @body, @message = args
        end

        @success = (200..299).cover?(@code)
        @error = parse_error(body) unless @success
      end

      def success?
        @success
      end

      private

      def parse_error(body)
        return unless body =~ NOT_BLANK
        obj = JSON.parse(body)
        return obj['error'] if obj.kind_of?(Hash)
      rescue JSON::ParserError
        nil
      end
    end

    class Base
      extend Forwardable

      include Honeybadger::Logging::Helper

      def initialize(config)
        @config = config
      end

      # Internal: Process payload for feature.
      #
      # feature - A Symbol feature name (corresponds to HTTP endpoint). Current
      #           options are: :notices, :metrics, :traces.
      # payload - Any Object responding to #to_json.
      #
      # Examples:
      #
      #   backend.notify(:notices, Notice.new(...))
      #
      # Raises NotImplementedError
      def notify(feature, payload)
        raise NotImplementedError, 'must define #notify on subclass.'
      end

      private

      attr_reader :config
    end
  end
end
