module Honeybadger
  class Config
    class Mash
      KEYS = DEFAULTS.keys.map(&:to_s).freeze

      def initialize(config, prefix: nil, hash: {})
        @config = config
        @prefix = prefix
        @hash = hash
      end

      def to_hash
        hash.to_hash
      end
      alias to_h to_hash

      private

      attr_reader :config, :prefix, :hash

      def method_missing(method_name, *args, &block)
        m = method_name.to_s
        if mash?(m)
          return Mash.new(config, prefix: key(m), hash: hash)
        elsif setter?(m)
          return hash.send(:[]=, key(m).to_sym, args[0])
        elsif getter?(m)
          k = key(m).to_sym
          if hash.has_key?(k)
            return hash[k]
          else
            return config[k]
          end
        end

        super
      end

      def respond_to_missing?(method_name, include_private = false)
        true
      end

      def mash?(method)
        key = [prefix, method.to_s + '.'].compact.join('.')
        KEYS.any? {|k| k.start_with?(key) }
      end

      def setter?(method_name)
        return false unless method_name.to_s =~ /=\z/
        key = key(method_name)
        KEYS.any? {|k| k == key }
      end

      def getter?(method_name)
        key = key(method_name)
        KEYS.any? {|k| k == key }
      end

      def key(method_name)
        parts = [prefix, method_name.to_s.chomp('=')]
        parts.compact!
        parts.join('.')
      end
    end

    class Ruby < Mash
      def logger=(logger)
        hash[:logger] = logger
      end

      def backend=(backend)
        hash[:backend] = backend
      end
    end
  end
end
