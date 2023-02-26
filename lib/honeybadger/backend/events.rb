# frozen_string_literal: true

require 'honeybadger/backend/base'
require 'honeybadger/util/http'

module Honeybadger
  module Backend
    # Backend used by the logger feature
    class Events < Base
      DEFAULT_HEADERS = {
        "Connection"   => "keep-alive",
        "Keep-Alive"   => "300",
      }.freeze

      def initialize(config)
        url = "http://honeybadger:#{config[:api_key]}@localhost:4567/v1/events"
        uri = URI.parse(url)

        http_config = OpenStruct.new({
          'connection.host' => uri.host,
          'connection_port' => uri.port,
          'connection.secure' => uri.scheme == "https",
          'logger' => config.logger,
        })
        @http = Util::HTTP.new(http_config)

        @headers = DEFAULT_HEADERS.merge({
          'authorization' => 'Basic ' + ["#{uri.user}:#{uri.password}"].pack('m0'),
        })
        @path = uri.path
        super
      end

      def notify(feature, payload)
        def payload.to_json; self; end # The HTTP util calls to_json
        Response.new(@http.post(@path, payload, @headers))
      rescue *Util::HTTP::ERRORS => e
        Response.new(:error, nil, "HTTP Error: #{e.class}")
      end
    end
  end
end
