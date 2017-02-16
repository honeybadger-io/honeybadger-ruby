require 'sinatra/base'
require 'honeybadger/ruby'

module Honeybadger
  module Init
    module Sinatra
      ::Sinatra::Base.class_eval do
        class << self
          def build_with_honeybadger(*args, &block)
            configure_honeybadger
            install_honeybadger
            build_without_honeybadger(*args, &block)
          end
          alias :build_without_honeybadger :build
          alias :build :build_with_honeybadger

          def configure_honeybadger
            return unless defined?(honeybadger_api_key)
            Honeybadger.configure do |config|
              config.api_key = honeybadger_api_key
            end
          end

          def install_honeybadger
            config = Honeybadger.config
            return unless config[:'sinatra.enabled']
            install_honeybadger_middleware(Honeybadger::Rack::ErrorNotifier) if config[:'exceptions.enabled']
          end

          def install_honeybadger_middleware(klass)
            return if middleware.any? {|m| m[0] == klass }
            use(klass)
          end
        end
      end
    end
  end
end

Honeybadger.init!({
  env: ENV['APP_ENV'] || ENV['RACK_ENV'],
  framework: :sinatra,
  :'logging.path' => 'STDOUT'
})

Honeybadger.load_plugins!
