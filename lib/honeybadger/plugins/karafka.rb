require 'honeybadger/plugin'
require 'honeybadger/karafka_subscriber'

module Honeybadger
  module Plugins
    Plugin.register :karafka do
      requirement { defined?(::Karafka) && ::Karafka.respond_to?(:monitor) }

      execution do
        if config.load_plugin_insights?(:karafka)
          ::Karafka.monitor.subscribe(::Honeybadger::KarafkaListener.new)
        end
      end
    end
  end
end
