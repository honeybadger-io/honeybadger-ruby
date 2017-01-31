require 'bigdecimal'
require 'set'

module Honeybadger
  module Util
    # Internal: Sanitizer sanitizes data for sending to Honeybadger's API. The
    # filters are based on Rails' HTTP parameter filter.
    class Sanitizer
      COOKIE_PAIRS = /[;,]\s?/
      COOKIE_SEP = '='.freeze
      COOKIE_PAIR_SEP = '; '.freeze

      ENCODE_OPTS = { invalid: :replace, undef: :replace, replace: '?'.freeze }.freeze

      FILTERED = '[FILTERED]'.freeze

      IMMUTABLE = [NilClass, FalseClass, TrueClass, Symbol, Numeric, BigDecimal, Method].freeze

      MAX_STRING_SIZE = 65536

      TRUNCATION_REPLACEMENT = '[TRUNCATED]'.freeze

      VALID_ENCODINGS = [Encoding::UTF_8, Encoding::ISO_8859_1].freeze

      def self.sanitize(data)
        @sanitizer ||= new
        @sanitizer.sanitize(data)
      end

      def initialize(max_depth: 20, filters: [])
        @filters = !filters.empty?
        @max_depth = max_depth

        strings, @regexps, @blocks = [], [], []

        filters.each do |item|
          case item
          when Proc
            @blocks << item
          when Regexp
            @regexps << item
          else
            strings << Regexp.escape(item.to_s)
          end
        end

        @deep_regexps, @regexps = @regexps.partition { |r| r.to_s.include?('\\.'.freeze) }
        deep_strings, @strings = strings.partition { |s| s.include?('\\.'.freeze) }

        @regexps << Regexp.new(strings.join('|'.freeze), true) unless strings.empty?
        @deep_regexps << Regexp.new(deep_strings.join('|'.freeze), true) unless deep_strings.empty?
      end

      def sanitize(data, depth = 0, stack = nil, parents = [])
        if enumerable?(data)
          return '[possible infinite recursion halted]'.freeze if stack && stack.include?(data.object_id)
          stack = stack ? stack.dup : Set.new
          stack << data.object_id
        end

        case data
        when Hash
          return '[max depth reached]'.freeze if depth >= max_depth
          hash = data.to_hash
          new_hash = {}
          hash.each_pair do |key, value|
            parents.push(key) if deep_regexps
            key = key.kind_of?(Symbol) ? key : sanitize(key, depth+1, stack, parents)
            if filter_key?(key, parents)
              new_hash[key] = FILTERED
            else
              value = sanitize(value, depth+1, stack, parents)
              if blocks.any? && !enumerable?(value)
                key = key.dup if can_dup?(key)
                value = value.dup if can_dup?(value)
                blocks.each { |b| b.call(key, value) }
              end
              new_hash[key] = value
            end
            parents.pop if deep_regexps
          end
          new_hash
        when Array, Set
          return '[max depth reached]'.freeze if depth >= max_depth
          data.to_a.map do |value|
            sanitize(value, depth+1, stack, parents)
          end
        when Numeric, TrueClass, FalseClass, NilClass
          data
        when String
          sanitize_string(data)
        else # all other objects:
          data.respond_to?(:to_s) ? sanitize_string(data.to_s) : nil
        end
      end

      def sanitize_string(string)
        string = valid_encoding(string.to_s)
        return string unless string.respond_to?(:size) && string.size > MAX_STRING_SIZE
        string[0...MAX_STRING_SIZE] + TRUNCATION_REPLACEMENT
      end

      def filter_cookies(raw_cookies)
        return raw_cookies unless filters?

        cookies = []

        raw_cookies.to_s.split(COOKIE_PAIRS).each do |pair|
          name, values = pair.split(COOKIE_SEP, 2)
          values = FILTERED if filter_key?(name)
          cookies << "#{name}=#{values}"
        end

        cookies.join(COOKIE_PAIR_SEP)
      end

      def filter_url(url)
        return url unless filters?

        filtered_url = url.to_s.dup

        filtered_url.scan(/(?:^|&|\?)([^=?&]+)=([^&]+)/).each do |m|
          next unless filter_key?(m[0])
          filtered_url.gsub!(/#{Regexp.escape(m[1])}/, FILTERED)
        end

        filtered_url
      end

    private

      attr_reader :max_depth, :regexps, :deep_regexps, :blocks

      def filters?
        !!@filters
      end

      def filter_key?(key, parents = nil)
        return false unless filters?
        return true if regexps.any? { |r| key =~ r }
        return true if deep_regexps && parents && (joined = parents.join(".")) && deep_regexps.any? { |r| joined =~ r }
        false
      end

      def valid_encoding?(string)
        string.valid_encoding? && (
          VALID_ENCODINGS.include?(string.encoding) ||
          VALID_ENCODINGS.include?(Encoding.compatible?(''.freeze, string))
        )
      end

      def valid_encoding(string)
        return string if valid_encoding?(string)
        string.encode(Encoding::UTF_8, ENCODE_OPTS)
      end

      def enumerable?(data)
        data.kind_of?(Hash) || data.kind_of?(Array) || data.kind_of?(Set)
      end

      def can_dup?(obj)
        !IMMUTABLE.any? {|k| obj.kind_of?(k) }
      end
    end
  end
end
