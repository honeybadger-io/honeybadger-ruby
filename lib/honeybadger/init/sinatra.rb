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
            # Sinatra is a special case. Sinatra starts the web application in an at_exit
            # handler. And, since we require sinatra before requiring HB, the only way to
            # setup our at_exit callback is in the sinatra build callback honeybadger/init/sinatra.rb
            Honeybadger.install_at_exit_callback
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
            if config[:'exceptions.enabled']
              # These two must come before the ErrorNotifier, since an error/response
              # passes through middleware from inner to outer (bottom to top)
              install_honeybadger_middleware(Honeybadger::Rack::UserFeedback)
              install_honeybadger_middleware(Honeybadger::Rack::UserInformer)
              install_honeybadger_middleware(Honeybadger::Rack::ErrorNotifier)
            end
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
