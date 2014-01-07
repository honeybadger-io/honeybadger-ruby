module Honeybadger
  class Sender
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
        :http_read_timeout,
        :max_retries
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
        log(:error, "Can't send error report -- the gem has been deactivated by the remote service.  Try restarting your app or contacting support@honeybadger.io.")
        return nil
      end

      notice = JSON.parse(notice) if notice.is_a?(String)
      api_key = api_key_ok?(notice['api_key']) or return nil

      send_request(:notices, notice, {'X-API-Key' => api_key}).fetch('id')
    rescue InvalidResponseError => e
      Honeybadger.configuration.features['notices'] = false if Net::HTTPForbidden === e.response
      nil
    rescue Error
      nil
    rescue StandardError => e
      log(:error, "[Honeybadger::Sender#send_to_honeybadger] Error: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
      nil
    end

    def ping(data = {})
      return nil unless api_key_ok?
      send_request(:ping, data)
    rescue Error
      nil
    rescue StandardError => e
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
      :http_read_timeout,
      :max_retries

    alias_method :secure?, :secure
    alias_method :use_system_ssl_cert_chain?, :use_system_ssl_cert_chain

    private

    def uri
      URI.parse("#{protocol}://#{host}:#{port}").merge('/v1/')
    end

    def api_key_ok?(api_key = nil)
      api_key ||= self.api_key
      unless api_key =~ /\S/
        log(:error, "API key not found.")
        return nil
      end

      api_key
    end

    def log(level, message)
      Honeybadger.write_verbose_log(message, level)
    end

    def send_request(path, data, headers={})
      log_prefix = path.to_s.upcase
      json = data.to_json

      log(:debug, "[#{log_prefix}] Data: #{json}") if Honeybadger.configuration.debug

      Error.retry(max_retries) do
        Error.wrap_http_errors do
          response = http_connection.post(uri.merge("#{path.to_s}/").path, json, http_headers(headers))

          log(Honeybadger.configuration.debug ? :info : :debug, "[#{log_prefix}] Response from Honeybadger: #{response.class}" + (response.body =~ /\S/ ? "\n#{response.body}" : ""))

          if Net::HTTPSuccess === response
            JSON.parse(response.body)
          else
            message = response.message =~ /\S/ ? response.message : response.class
            fail InvalidResponseError.new("Invalid HTTP response: #{message}", response)
          end
        end
      end
    rescue Error => e
      log(:error, "[#{log_prefix}] Failure: #{e} (retried #{e.retries} time(s))")
      raise e
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
      http = http_class.new(uri.host, uri.port)

      http.read_timeout = http_read_timeout
      http.open_timeout = http_open_timeout

      if secure?
        http.use_ssl      = true
        http.ca_file      = Honeybadger.configuration.ca_bundle_path
        http.verify_mode  = OpenSSL::SSL::VERIFY_PEER
      else
        http.use_ssl      = false
      end

      http
    rescue => e
      log(:error, "[Honeybadger::Sender#setup_http_connection] Failure initializing the HTTP connection.\nError: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
      raise e
    end
  end
end
