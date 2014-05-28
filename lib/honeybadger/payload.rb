require 'delegate'

module Honeybadger
  class Payload < SimpleDelegator
    TOP_LEVEL_KEYS = [:api_key, :notifier, :error, :request, :server]
    OBJECT_WHITELIST = [Hash, Array, String, Integer, Float, TrueClass, FalseClass, NilClass]

    # Define getters for top level keys
    TOP_LEVEL_KEYS.each do |key|
      define_method key do
        self[key]
      end
    end

    def initialize(hash = {}, options = {})
      fail ArgumentError, 'must be a Hash' unless hash.kind_of?(Hash)

      @max_depth = options[:max_depth] || 20
      @filters = options[:filters]

      super(sanitize(hash))

      TOP_LEVEL_KEYS.each {|k| self[k] ||= {} }

      filter_url!(request[:url]) if request[:url]
      filter_urls!(request[:cgi_data]) if request[:cgi_data]

      filter!(request[:params]) if request[:params]
      filter!(request[:session]) if request[:session]
      filter!(request[:cgi_data]) if request[:cgi_data]
      filter!(request[:local_variables]) if request[:local_variables]
    end

    protected

    attr_reader :max_depth, :filters

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

    def filter!(hash)
      if filters
        hash.each do |key, value|
          if filter_key?(key)
            hash[key] = "[FILTERED]"
          elsif value.respond_to?(:to_hash)
            filter!(hash[key])
          end
        end
      end
    end

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

    def filter_url!(url)
      return nil unless url =~ /\S/

      url.scan(/(?:^|&|\?)([^=?&]+)=([^&]+)/).each do |m|
        next unless filter_key?(m[0])
        url.gsub!(/#{m[1]}/, '[FILTERED]')
      end

      url
    end

    def filter_urls!(hash)
      hash.each_pair do |key, value|
        next unless value.kind_of?(String) && key =~ /\A[A-Z_]+\Z/ && value =~ /\S/
        filter_url!(value)
      end
    end
  end
end
