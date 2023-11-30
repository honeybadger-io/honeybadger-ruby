require 'honeybadger/util/http'
require 'base64'

module Honeybadger
  module Util
    class AppHTTP < HTTP
      def personal_auth_headers
        encoded_token = Base64.encode64("#{config[:personal_auth_token]}:")
        {"Authorization" => "Basic #{encoded_token}"}
      end

      def http_headers(headers = nil)
        {}.tap do |hash|
          hash.merge!(HEADERS)
          hash.merge!(personal_auth_headers)
          hash.merge!(headers) if headers
        end
      end

      def host
        config[:'connection.app_host']
      end


      def get(endpoint, headers = nil)
        response = http_connection.get(endpoint, http_headers(headers))
        debug { sprintf("http method=GET path=%s code=%d", endpoint.dump, response.code) }
        response
      end

      def put(endpoint, payload, headers = nil)
        response = http_connection.put(endpoint, compress(payload.to_json), http_headers(headers))
        debug { sprintf("http method=PUT path=%s code=%d", endpoint.dump, response.code) }
        response
      end
      
      def delete(endpoint, headers = nil)
        response = http_connection.delete(endpoint, http_headers(headers))
        debug { sprintf("http method=DELETE path=%s code=%d", endpoint.dump, response.code) }
        response
      end
    end
  end
end
