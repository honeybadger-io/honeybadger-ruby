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
    # notice - The notice data to be sent (Hash or JSON string)
    #
    # Returns nothing
    def send_to_honeybadger(notice)
      data = notice.respond_to?(:to_json) ? notice.to_json : notice

      http     = setup_http_connection
      headers  = HEADERS

      headers.merge!({ 'X-API-Key' => api_key}) if api_key.present?

      response = begin
                   http.post(url.path, data, headers)
                 rescue *HTTP_ERRORS => e
                   log(:error, "Unable to contact the Honeybadger server. HTTP Error=#{e}")
                   nil
                 end

      case response
      when Net::HTTPSuccess then
        log(:info, "Success: #{response.class}", response, data)
      else
        log(:error, "Failure: #{response.class}", response, data)
      end

      if response && response.respond_to?(:body)
        notice = JSON.parse(response.body)
        error_id = notice['id']
      end
    rescue => e
      log(:error, "[Honeybadger::Sender#send_to_honeybadger] Cannot send notification. Error: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
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

    def log(level, message, response = nil, data = nil)
      if logger
        logger.send(level, LOG_PREFIX + message)

        # Log the notice payload for debugging
        logger.debug(LOG_PREFIX + "Notice: #{data}") if data
      end

      Honeybadger.report_environment_info
      Honeybadger.report_response_body(response.body) if response && response.respond_to?(:body)
    end

    def logger
      Honeybadger.logger
    end

    def setup_http_connection
      http =
        Net::HTTP::Proxy(proxy_host, proxy_port, proxy_user, proxy_pass).
          new(url.host, url.port)

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
  end
end
