require 'honeybadger/util/sanitizer'

module Honeybadger
  module Util
    # Internal: Constructs/sanitizes request data for notices and traces.
    module RequestPayload
      # Internal: default values to use for request data.
      DEFAULTS = {
        url: nil,
        component: nil,
        action: nil,
        params: {}.freeze,
        session: {}.freeze,
        cgi_data: {}.freeze
      }.freeze

      # Internal: allowed keys.
      KEYS = DEFAULTS.keys.freeze

      def self.build(opts = {})
        sanitizer = opts.fetch(:sanitizer) { Sanitizer.new }

        payload = DEFAULTS.dup
        KEYS.each do |key|
          next unless opts[key]
          payload[key] = sanitizer.sanitize(opts[key])
        end

        payload[:session] = opts[:session][:data] if opts[:session] && opts[:session][:data]
        payload[:url] = sanitizer.filter_url(payload[:url]) if payload[:url]
        if payload[:cgi_data]["HTTP_COOKIE"]
          payload[:cgi_data]["HTTP_COOKIE"] = sanitizer.filter_cookies(payload[:cgi_data]["HTTP_COOKIE"])
        end

        payload
      end
    end
  end
end
