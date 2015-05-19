require 'honeybadger/util/sanitizer'

module Honeybadger
  module Util
    # Internal: Constructs/sanitizes request data for notices and traces.
    class RequestPayload
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

      def initialize(opts = {})
        @sanitizer = opts.fetch(:sanitizer) { Sanitizer.new }
        @payload = {}
        KEYS.each do |key|
          @payload[key] = opts[key] || DEFAULTS[key]
        end
        @payload[:session] = opts[:session][:data] if opts[:session] && opts[:session][:data]
      end

      # Internal: Define dynamic getters for payload attributes.
      KEYS.each do |key|
        define_method key do  # def component
          @payload[key]       #   @payload[:component]
        end                   # end
      end

      def to_hash
        h = {}

        KEYS.each do |key|
          h[key] = s(payload[key])
        end

        h[:url] = sanitizer.filter_url(h[:url]) if h[:url]

        h
      end

      def to_json
        to_hash.to_json
      end

      # Private helpers

      attr_reader :sanitizer, :payload

      def [](key)
        payload[key]
      end

      def []=(key, value)
        payload[key] = value
      end

      def has_key?(key)
        payload.has_key?(key)
      end

      private

      def s(data)
        sanitizer.sanitize(data)
      end

      def f(data)
      end
    end
  end
end
