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
          return get(key(m))
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

      def get(key)
        k = key.to_sym
        return hash[k] if hash.has_key?(k)
        config.get(k)
      end
    end

    class Ruby < Mash
      def logger=(logger)
        hash[:logger] = logger
      end

      def logger
        get(:logger)
      end

      def backend=(backend)
        hash[:backend] = backend
      end

      def backend
        get(:backend)
      end

      def backtrace_filter
        hash[:backtrace_filter] = Proc.new if block_given?
        get(:backtrace_filter)
      end

      def exception_filter
        hash[:exception_filter] = Proc.new if block_given?
        get(:exception_filter)
      end

      def exception_fingerprint
        hash[:exception_fingerprint] = Proc.new if block_given?
        get(:exception_fingerprint)
      end
    end
  end
end
