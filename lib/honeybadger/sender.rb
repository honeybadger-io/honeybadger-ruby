require 'zlib'
require 'stringio'

module Honeybadger
  class Sender
    NOTICES_URI = '/v1/notices/'.freeze
    HTTP_ERRORS = [Timeout::Error,
                   Errno::EINVAL,
                   Errno::ECONNRESET,
                   EOFError,
                   Net::HTTPBadResponse,
                   Net::HTTPHeaderSyntaxError,
                   Net::ProtocolError,
                   Errno::ECONNREFUSED].freeze

    def initialize(options = {})
      [ :api_key,
        :proxy_host,
        :proxy_port,
        :proxy_user,
        :proxy_pass,
        :protocol,
        :host,
        :port,
        :secure,
        :use_system_ssl_cert_chain,
        :http_open_timeout,
        :http_read_timeout
      ].each do |option|
        instance_variable_set("@#{option}", options[option])
      end
    end

    # Public: Sends the notice data off to Honeybadger for processing.
    #
    # notice - The notice to be sent (Notice, Hash or JSON string)
    #
    # Returns error id from successful response
    def send_to_honeybadger(notice)
      if !Honeybadger.configuration.features['notices']
        log(:error, "Can't send error report -- the gem has been deactivated by the remote service.\n\t" \
            "This is usually a result of an expired plan. Please check your payment info and restart your app.\n\t" \
            "If you continue to receive this message, contact support@honeybadger.io.")
        return nil
      end

      api_key = api_key_ok?(!notice.is_a?(String) && notice['api_key']) or return nil

      data = notice.is_a?(String) ? notice : notice.to_json

      response = send_request(url.path, data, {'X-API-Key' => api_key})

      if Net::HTTPSuccess === response
        log(Honeybadger.configuration.debug ? :info : :debug, "Success: #{response.class}", response, data)
        JSON.parse(response.body).fetch('id')
      else
        Honeybadger.configuration.features['notices'] = false if Net::HTTPForbidden === response
        log(:error, "Failure: #{response.class}", response, data)
        log_original_exception(notice)
        nil
      end
    rescue => e
      log(:error, "[Honeybadger::Sender#send_to_honeybadger] Error: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
      log_original_exception(notice)
      nil
    end

    def ping(data = {})
      return nil unless api_key_ok?

      data = data.to_json
      response = send_request('/v1/ping/', data)

      if Net::HTTPSuccess === response
        log(Honeybadger.configuration.debug ? :info : :debug, "Ping Success: #{response.class}", response)
        JSON.parse(response.body)
      else
        log(:error, "Ping Failure: #{response.class}", response, data)
        nil
      end
    rescue => e
      log(:error, "[Honeybadger::Sender#ping] Error: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
      nil
    end

    attr_reader :api_key,
      :proxy_host,
      :proxy_port,
      :proxy_user,
      :proxy_pass,
      :protocol,
      :host,
      :port,
      :secure,
      :use_system_ssl_cert_chain,
      :http_open_timeout,
      :http_read_timeout

    alias_method :secure?, :secure
    alias_method :use_system_ssl_cert_chain?, :use_system_ssl_cert_chain

    private

    def url
      URI.parse("#{protocol}://#{host}:#{port}").merge(NOTICES_URI)
    end

    def api_key_ok?(api_key = nil)
      api_key ||= self.api_key
      unless api_key =~ /\S/
        log(:error, "API key not found.")
        return nil
      end

      api_key
    end

    def log(level, message, response = nil, data = nil)
      # Log result:
      Honeybadger.write_verbose_log(message, level)

      # Log debug information:
      Honeybadger.report_environment_info
      Honeybadger.report_response_body(response.body) if response && response.body =~ /\S/
      Honeybadger.write_verbose_log("Notice: #{data}", :debug) if data && Honeybadger.configuration.debug
    end

    def send_request(path, data, headers = {})
      http_connection.post(path, compress(data), http_headers(headers))
    rescue *HTTP_ERRORS => e
      log(:error, "Unable to contact the Honeybadger server. HTTP Error=#{e}")
      nil
    end

    def http_connection
      setup_http_connection
    end

    def http_headers(headers=nil)
      {}.tap do |hash|
        hash.merge!(HEADERS)
        hash.merge!({'X-API-Key' => api_key})
        hash.merge!(headers) if headers
      end
    end

    def setup_http_connection
      http_class = Net::HTTP::Proxy(proxy_host, proxy_port, proxy_user, proxy_pass)
      http = http_class.new(url.host, url.port)

      http.read_timeout = http_read_timeout
      http.open_timeout = http_open_timeout

      if secure?
        http.use_ssl     = true

        http.ca_file      = Honeybadger.configuration.ca_bundle_path
        http.verify_mode  = OpenSSL::SSL::VERIFY_PEER
      else
        http.use_ssl     = false
      end

      http
    rescue => e
      log(:error, "[Honeybadger::Sender#setup_http_connection] Failure initializing the HTTP connection.\nError: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
      raise e
    end

    def log_original_exception(notice)
      if Honeybadger.configuration.log_exception_on_send_failure
        if notice.respond_to?(:exception) && notice.respond_to?(:backtrace)
          message = "#{notice.error_message}\n#{notice.backtrace}"
        else
          message = "#{notice}"
        end

        Honeybadger.write_verbose_log("Original Exception: #{message}", :error)
      end
    end

    def compress(string, level = Zlib::DEFAULT_COMPRESSION)
      Zlib::Deflate.deflate(string, level)
    end
  end
end
