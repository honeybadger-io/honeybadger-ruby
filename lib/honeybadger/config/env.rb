module Honeybadger
  class Config
    class Env < ::Hash
      CONFIG_KEY = /\AHONEYBADGER_(.+)\Z/.freeze
      CONFIG_MAPPING = Hash[DEFAULTS.keys.map {|k| [k.to_s.upcase.gsub(KEY_REPLACEMENT, '_'), k] }].freeze
      ARRAY_VALUES = Regexp.new('\s*,\s*').freeze

      def initialize(env = ENV)
        env.each_pair do |k,v|
          next unless k.match(CONFIG_KEY)
          next if DISALLOWED_KEYS.include?(CONFIG_MAPPING[$1])
          self[CONFIG_MAPPING[$1] || $1.downcase.to_sym] = cast_value(v)
        end
      end

      private

      def cast_value(value)
        if value.match(ARRAY_VALUES)
          return value.split(ARRAY_VALUES).map(&method(:cast_value))
        end

        case value
        when /\Atrue\Z/
          true
        when /\Afalse\Z/
          false
        when /\Anil\Z/
          nil
        when /\A\d+\z/
          value.to_i
        when /\A\d+\.\d+\z/
          value.to_f
        else
          value.to_s
        end
      end
    end
  end
end
