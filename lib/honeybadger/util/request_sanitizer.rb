module Honeybadger
  module Util
    class RequestSanitizer

      def initialize(sanitizer)
        @sanitizer = sanitizer
      end

      def sanitize(request_hash)
        request_hash.merge({
          url: sanitize_url(request_hash[:url]),
          component: request_hash[:component],
          action: request_hash[:action],
          params: sanitize_hash(request_hash[:params]),
          session: sanitize_hash(request_hash[:session]),
          cgi_data: sanitize_hash(request_hash[:cgi_data])
        })
      end

      private

      def sanitize_url(url)
        if url
          @sanitizer.filter_url(url)
        end
      end

      def sanitize_hash(hash)
        if hash
          @sanitizer.filter(@sanitizer.sanitize(hash))
        end
      end
    end
  end
end
