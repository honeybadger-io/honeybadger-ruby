module Honeybadger
  module Util
    class Sanitizer
      OBJECT_WHITELIST = [Hash, Array, String, Integer, Float, TrueClass, FalseClass, NilClass]

      FILTERED_REPLACEMENT = '[FILTERED]'.freeze

      def initialize(opts = {})
        @max_depth = opts.fetch(:max_depth, 20)
        @filters = Array(opts.fetch(:filters, nil)).collect do |f|
          f.kind_of?(Regexp) ? f : f.to_s
        end
      end

      def sanitize(data, depth = 0, stack = nil)
        if recursive?(data)
          return '[possible infinite recursion halted]' if stack && stack.include?(data.object_id)
          stack = stack ? stack.dup : Set.new
          stack << data.object_id
        end

        if data.kind_of?(String)
          sanitize_string(data)
        elsif data.kind_of?(Hash)
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
        elsif data.kind_of?(Array) || data.kind_of?(Set)
          return '[max depth reached]' if depth >= max_depth
          data.map do |value|
            sanitize(value, depth+1, stack)
          end.compact
        elsif OBJECT_WHITELIST.any? {|c| data.kind_of?(c) }
          data
        else
          sanitize_string(data.to_s)
        end
      end

      def filter_url(url)
        filtered_url = url.to_s.dup
        filtered_url.scan(/(?:^|&|\?)([^=?&]+)=([^&]+)/).each do |m|
          next unless filter_key?(m[0])
          filtered_url.gsub!(/#{m[1]}/, '[FILTERED]')
        end

        filtered_url
      end

      private

      VALID_ENCODINGS = [Encoding::UTF_8, Encoding::ISO_8859_1].freeze
      ENCODE_OPTS = { invalid: :replace, undef: :replace, replace: '?'.freeze }.freeze
      UTF8_STRING = ''.freeze

      attr_reader :max_depth, :filters

      def recursive?(data)
        data.kind_of?(Hash) || data.kind_of?(Array) || data.kind_of?(Set)
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

      def valid_encoding?(data)
         data.valid_encoding? && (
           VALID_ENCODINGS.include?(data.encoding) ||
           VALID_ENCODINGS.include?(Encoding.compatible?(UTF8_STRING, data))
         )
      end

      def sanitize_string(data)
        return data if valid_encoding?(data)

        if data.encoding == Encoding::UTF_8
          data.encode(Encoding::UTF_16, ENCODE_OPTS).encode!(Encoding::UTF_8)
        else
          data.encode(Encoding::UTF_8, ENCODE_OPTS)
        end
      end
    end
  end
end
