module Honeybadger
  class Config
    class Ruby < Hash
      MAPPING = DEFAULTS.keys.map {|k| [k.to_s.gsub(/\./, '_').to_sym, k] }.to_h

      def logger=(logger)
        self[:logger] = logger
      end

      def method_missing(method_name, *args, &block)
        if key = MAPPING.keys.find {|k| method_name == k }
          self.send(:[], MAPPING[key], &block)
        elsif key = MAPPING.keys.find {|k| method_name == :"#{k}=" }
          self.send(:[]=, MAPPING[key], *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        MAPPING.keys.any? {|k| method_name.to_s.start_with?(k) } || super
      end
    end
  end
end
