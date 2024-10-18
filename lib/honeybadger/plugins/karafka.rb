require 'honeybadger/plugin'
require 'honeybadger/karafka'

module Honeybadger
  module Plugins
    Plugin.register :karafka do
      requirement { defined?(::Karafka) && ::Karafka.respond_to?(:monitor) }

      execution do
        ::Karafka.monitor.subscribe(::Honeybadger::Karafka::ErrorsListener.new)

        if config.load_plugin_insights?(:karafka)
          ::Karafka.monitor.subscribe(::Honeybadger::Karafka::InsightsListener.new)
        end
      end
    end
  end
end
