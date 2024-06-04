require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    Plugin.register :karafka do
      requirement { defined?(::Karafka) }

      execution do
        ::Karafka.monitor.subscribe('error.occurred') do |event|
          Honeybadger.notify(event[:error])
          Honeybadger.event('error.occurred', error: event[:error]) if config.load_plugin_insights?(:karafka)
        end

        if config.load_plugin_insights?(:karafka)
          ::Karafka.monitor.subscribe("consumer.consumed") do |event|
            context = {
              duration: event.payload[:time],
              consumer: event.payload[:caller].class.to_s,
              id: event.payload[:caller].id,
              topic: event.payload[:caller].messages.metadata.topic,
              messages_count: event.payload[:caller].messages.metadata.size,
              partition: event.payload[:caller].messages.metadata.partition
            }

            Honeybadger.event('consumer.consumed.karafka', context)
          end
        end
      end
    end
  end
end
