module Honeybadger
  module Util
    class Sanitizer
      OBJECT_WHITELIST = [Hash, Array, String, Integer, Float, TrueClass, FalseClass, NilClass]

      def initialize(opts = {})
        @max_depth = opts[:max_depth] || 20
        @filters = Array(opts[:filters])
      end

      # Removes non-serializable data and truncates to max depth.
      def sanitize(data, depth = 0, stack = [])
        return '[possible infinite recursion halted]' if stack.any?{|item| item == data.object_id }

        if data.respond_to?(:to_hash)
          return '[max depth reached]' if depth >= max_depth
          data.to_hash.reduce({}) do |result, (key, value)|
            result.merge(key => sanitize(value, depth+1, stack + [data.object_id]))
          end
        elsif data.respond_to?(:to_ary)
          return '[max depth reached]' if depth >= max_depth
          data.to_ary.collect do |value|
            sanitize(value, depth+1, stack + [data.object_id])
          end
        elsif OBJECT_WHITELIST.any? {|c| data.kind_of?(c) }
          data
        else
          data.to_s
        end
      end

      def filter(hash)
        {}.tap do |filtered_hash|
          hash.each_pair do |key, value|
            if value.respond_to?(:to_hash)
              filtered_hash[key] = filter(hash[key])
            else
              filtered_hash[key] = filter_key?(key) ? '[FILTERED]' : hash[key]
            end
          end
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

      attr_reader :max_depth, :filters

      def filter_key?(key)
        return false unless filters

        filters.any? do |filter|
          if filter.is_a?(Regexp)
            key.to_s =~ filter
          else
            key.to_s.eql?(filter.to_s)
          end
        end
      end
    end
  end
end
