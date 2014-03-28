require 'delegate'

module Honeybadger
  class Payload < SimpleDelegator
    attr_reader :max_depth

    def initialize(hash = {}, options = {})
      fail ArgumentError, 'must be a Hash' unless hash.kind_of?(Hash)
      @max_depth = options[:max_depth] || 20
      super(hash)
      sanitize(self)
    end

    private

    def sanitize(hash, depth = 0)
      hash.each_pair do |k,v|
        next unless v.kind_of?(Hash)
        if depth >= max_depth
          hash.delete(k)
        else
          hash[k] = sanitize(v, depth+1)
        end
      end

      hash
    end
  end
end
