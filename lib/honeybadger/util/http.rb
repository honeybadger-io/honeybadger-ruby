module Honeybadger
  module Util
    class HTTP
      extend Forwardable

      include Honeybadger::Logging::Helper

      HEADERS = {
        'Content-type'.freeze => 'application/json'.freeze,
        'Content-Encoding'.freeze => 'deflate'.freeze,
        'Accept'.freeze => 'text/json, application/json'.freeze,
        'User-Agent'.freeze => "HB-Ruby #{VERSION}; #{RUBY_VERSION}; #{RUBY_PLATFORM}".freeze
      }.freeze

      def initialize(config)
        @config = config
      end

      def post(endpoint, payload, headers = nil)
        response = http_connection.post(endpoint, compress(payload.to_json), http_headers(headers))
        debug { sprintf("http method=POST path=%s code=%d", endpoint.dump, response.code) }
        response
      end

      private

      attr_reader :config

      def http_connection
        setup_http_connection
      end

      def http_headers(headers = nil)
        {}.tap do |hash|
          hash.merge!(HEADERS)
          hash.merge!({'X-API-Key' => config[:api_key].to_s})
          hash.merge!(headers) if headers
        end
      end

      def setup_http_connection
        http_class = Net::HTTP::Proxy(config[:'connection.proxy_host'], config[:'connection.proxy_port'], config[:'connection.proxy_user'], config[:'connection.proxy_pass'])
        http = http_class.new(config[:'connection.host'], config.connection_port)

        http.read_timeout = config[:'connection.http_read_timeout']
        http.open_timeout = config[:'connection.http_open_timeout']

        if config[:'connection.secure']
          http.use_ssl = true

          http.ca_file = config.ca_bundle_path
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        else
          http.use_ssl = false
        end

        http
      end

      def compress(string, level = Zlib::DEFAULT_COMPRESSION)
        Zlib::Deflate.deflate(string, level)
      end
    end
  end
end
