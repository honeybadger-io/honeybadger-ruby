require 'honeybadger/plugin'
require 'honeybadger/ruby'

module Honeybadger
  module Plugins
    Plugin.register do
      requirement { defined?(::Karafka) }

      execution do
        ::Karafka.monitor.subscribe('error.occurred') do |event|
          Honeybadger.notify(event[:error])
        end
      end
    end
  end
end
