require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    Plugin.register :karafka do
      requirement { defined?(::Karafka) && ::Karafka.respond_to?(:monitor) }

      execution do
        require 'honeybadger/karafka'

        if Honeybadger.config[:'exceptions.enabled']
          errors_listener = ::Honeybadger::Karafka::ErrorsListener.new
          ::Karafka.monitor.subscribe(errors_listener)
          ::Karafka.producer.monitor.subscribe(errors_listener) if ::Karafka.respond_to?(:producer)
        end

        if config.load_plugin_insights?(:karafka)
          ::Karafka.monitor.subscribe(::Honeybadger::Karafka::InsightsListener.new)
        end
      end
    end
  end
end
