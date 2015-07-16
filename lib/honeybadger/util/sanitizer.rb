module Honeybadger
  module Util
    class Sanitizer
      OBJECT_WHITELIST = [Hash, Array, String, Integer, Float, TrueClass, FalseClass, NilClass]

      FILTERED_REPLACEMENT = '[FILTERED]'.freeze

      TRUNCATION_REPLACEMENT = '[TRUNCATED]'.freeze

      MAX_STRING_SIZE = 2048

      COOKIE_PAIRS = /[;,]\s?/
      COOKIE_SEP = '='.freeze
      COOKIE_PAIR_SEP = '; '.freeze

      def initialize(opts = {})
        @max_depth = opts.fetch(:max_depth, 20)

        if filters = opts.fetch(:filters, nil)
          @filters = Array(filters).collect do |f|
            f.kind_of?(Regexp) ? f : f.to_s
          end
        end
      end

      def sanitize(data, depth = 0, stack = nil)
        if recursive?(data)
          return '[possible infinite recursion halted]' if stack && stack.include?(data.object_id)
          stack = stack ? stack.dup : Set.new
          stack << data.object_id
        end

        if data.kind_of?(String)
          self.class.sanitize_string(data)
        elsif data.respond_to?(:to_hash)
          return '[max depth reached]' if depth >= max_depth
          hash = data.to_hash
          new_hash = {}
          hash.each_pair do |key, value|
            k = key.kind_of?(Symbol) ? key : sanitize(key, depth+1, stack)
            if filter_key?(k)
              new_hash[k] = FILTERED_REPLACEMENT
            else
              new_hash[k] = sanitize(value, depth+1, stack)
            end
          end
          new_hash
        elsif data.respond_to?(:to_ary)
          return '[max depth reached]' if depth >= max_depth
          data.to_ary.map do |value|
            sanitize(value, depth+1, stack)
          end.compact
        elsif OBJECT_WHITELIST.any? {|c| data.kind_of?(c) }
          data
        else
          self.class.sanitize_string(data.to_s)
        end
      end

      def filter_cookies(raw_cookies)
        return raw_cookies unless filters

        cookies = []
        raw_cookies.split(COOKIE_PAIRS).each do |pair|
          name, values = pair.split(COOKIE_SEP, 2)
          values = FILTERED_REPLACEMENT if filter_key?(name)
          cookies << "#{ name }=#{ values }"
        end

        cookies.join(COOKIE_PAIR_SEP)
      end

      def filter_url(url)
        return url unless filters

        filtered_url = url.to_s.dup
        filtered_url.scan(/(?:^|&|\?)([^=?&]+)=([^&]+)/).each do |m|
          next unless filter_key?(m[0])
          filtered_url.gsub!(/#{m[1]}/, FILTERED_REPLACEMENT)
        end

        filtered_url
      end

      VALID_ENCODINGS = [Encoding::UTF_8, Encoding::ISO_8859_1].freeze
      ENCODE_OPTS = { invalid: :replace, undef: :replace, replace: '?'.freeze }.freeze
      UTF8_STRING = ''.freeze

      class << self

        def valid_encoding?(data)
           data.valid_encoding? && (
             VALID_ENCODINGS.include?(data.encoding) ||
             VALID_ENCODINGS.include?(Encoding.compatible?(UTF8_STRING, data))
           )
        end

        def valid_encoding(data)
          return data if valid_encoding?(data)

          if data.encoding == Encoding::UTF_8
            data.encode(Encoding::UTF_16, ENCODE_OPTS).encode!(Encoding::UTF_8)
          else
            data.encode(Encoding::UTF_8, ENCODE_OPTS)
          end
        end

        def sanitize_string(data)
          data = valid_encoding(data)
          return data unless data.respond_to?(:size) && data.size > MAX_STRING_SIZE
          data[0...MAX_STRING_SIZE] + TRUNCATION_REPLACEMENT
        end

      end

      private

      attr_reader :max_depth, :filters

      def recursive?(data)
        data.respond_to?(:to_hash) || data.respond_to?(:to_ary)
      end

      def filter_key?(key)
        return false unless filters

        filters.any? do |filter|
          if filter.is_a?(Regexp)
            filter =~ key.to_s
          else
            key.to_s.eql?(filter.to_s)
          end
        end
      end
    end
  end
end
