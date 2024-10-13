require 'honeybadger/plugin'
require 'honeybadger/karafka_subscriber'

module Honeybadger
  module Plugins
    Plugin.register :karafka do
      requirement { defined?(::Karafka) && ::Karafka.respond_to?(:monitor) }

      execution do
        Karafka.monitor.subscribe "error.occurred" do |event|
          tags = ["type:#{event[:type]}"]

          if (consumer = event.payload[:caller]).respond_to?(:messages)
            messages = consumer.messages
            metadata = messages.metadata
            consumer_group_id = consumer.topic.consumer_group.id

            tags += [
              "topic:#{metadata.topic}",
              "partition:#{metadata.partition}",
              "consumer_group:#{consumer_group_id}"
            ]
          end

          Honeybadger.notify(event[:error], tags: tags)
        end

        if config.load_plugin_insights?(:karafka)
          ::Karafka.monitor.subscribe(::Honeybadger::KarafkaSubscriber.new)
        end
      end
    end
  end
end
