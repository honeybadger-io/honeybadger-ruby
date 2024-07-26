# This is a simple copy from ActiveSupport:Cache for testing purposes
module ActiveSupport
  module Cache
    def self.expand_cache_key(key, namespace = nil)
      expanded_cache_key = namespace ? +"#{namespace}/" : +""
      expanded_cache_key << retrieve_cache_key(key)
      expanded_cache_key
    end

    def self.retrieve_cache_key(key)
      case
      when key.respond_to?(:cache_key_with_version) then key.cache_key_with_version
      when key.respond_to?(:cache_key)              then key.cache_key
      when key.is_a?(Array)                         then key.map { |element| retrieve_cache_key(element) }.to_s
      when key.respond_to?(:to_a)                   then retrieve_cache_key(key.to_a)
      else                                               key.to_s
      end.to_s
    end
  end
end
