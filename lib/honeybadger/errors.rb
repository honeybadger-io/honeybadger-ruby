module Honeybadger
  HTTP_ERRORS = [Timeout::Error,
                 Errno::EINVAL,
                 Errno::ECONNRESET,
                 EOFError,
                 Net::HTTPBadResponse,
                 Net::HTTPHeaderSyntaxError,
                 Net::ProtocolError,
                 Errno::ECONNREFUSED].freeze

  class Error < StandardError
    attr_accessor :retries
    attr_reader :original_error

    def initialize(message)
      @original_error = $!
      @retries = 0
      super
    end

    def retry?; false; end

    def self.retry(max_retries, &block)
      retries = 0
      begin
        yield
      rescue Error => e
        e.retries = retries
        if e.retry? && (retries += 1) <= max_retries
          retry
        else
          raise e
        end
      end
    end

    def self.wrap_http_errors(&block)
      yield
    rescue Error => e
      raise e
    rescue *HTTP_ERRORS => e
      raise HTTPError.new("Unable to contact the Honeybadger server. HTTP Error=#{e.class}")
    end
  end

  class HTTPError < Error
    def retry?
      HTTP_ERRORS.any? { |e| e === original_error }
    end
  end

  class InvalidResponseError < Error
    attr_reader :response

    def initialize(default_message, response)
      @response = response
      super(message_from(response) || default_message)
    end

    def retry?
      Net::HTTPInternalServerError === response
    end

    private

    def message_from(response)
      return unless response.body =~ /\S/
      JSON.parse(response.body)['error'] rescue nil
    end
  end
end
