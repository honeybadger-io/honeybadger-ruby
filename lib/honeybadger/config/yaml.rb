require 'pathname'
require 'yaml'
require 'erb'

module Honeybadger
  class Config
    class Yaml < ::Hash
      def initialize(path, env = 'production')
        @path = path.kind_of?(Pathname) ? path : Pathname.new(path)

        if !@path.exist?
          raise ConfigError, "The configuration file #{@path} was not found."
        elsif !@path.file?
          raise ConfigError, "The configuration file #{@path} is not a file."
        elsif !@path.readable?
          raise ConfigError, "The configuration file #{@path} is not readable."
        else
          yaml = YAML.load(ERB.new(@path.read).result)
          yaml.merge!(yaml[env]) if yaml[env].kind_of?(Hash)
          update(dotify_keys(yaml))
        end
      end

      private

      def dotify_keys(hash, key_prefix = nil)
        {}.tap do |new_hash|
          hash.each_pair do |k,v|
            k = [key_prefix, k].compact.join('.')
            if v.kind_of?(Hash)
              new_hash.update(dotify_keys(v, k))
            else
              next if DISALLOWED_KEYS.include?(k.to_sym)
              new_hash[k.to_sym] = v
            end
          end
        end
      end
    end
  end
end
