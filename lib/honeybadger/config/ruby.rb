module Honeybadger
  class Config
    class Ruby < Hash
      KEYS = DEFAULTS.keys.map {|k| k.to_s.gsub(/\./, '_') }

      def logger=(logger)
        self[:logger] = logger
      end

      def method_missing(method_name, *args, &block)
        if key = KEYS.find {|k| method_name == k.to_sym }
          self.send(:[], *args, &block)
        elsif key = KEYS.find {|k| method_name == :"#{k}=" }
          self.send(:[]=, key.to_sym, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        KEYS.any? {|k| method_name.to_s.start_with?(k) } || super
      end
    end
  end
end
