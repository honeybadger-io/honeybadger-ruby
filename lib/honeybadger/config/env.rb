module Honeybadger
  class Config
    class Env < ::Hash
      CONFIG_KEY = /\AHONEYBADGER_(.+)\Z/.freeze
      CONFIG_MAPPING = Hash[DEFAULTS.keys.map {|k| [k.to_s.upcase.gsub(KEY_REPLACEMENT, '_'), k] }].freeze
      ARRAY_VALUES = Regexp.new('\s*,\s*').freeze

      def initialize(env = ENV)
        env.each_pair do |k,v|
          next unless k.match(CONFIG_KEY)
          next unless config_key = CONFIG_MAPPING[$1]
          self[config_key] = cast_value(v, OPTIONS[config_key][:type])
        end
      end

      private

      def cast_value(value, type = String)
        v = value.to_s

        if type == Boolean
          !!(v =~ /\A(true|t|1)\z/i)
        elsif type == Array
          v.split(ARRAY_VALUES).map(&method(:cast_value))
        elsif type == Integer
          v.to_i
        elsif type == Float
          v.to_f
        else
          v
        end
      end
    end
  end
end
