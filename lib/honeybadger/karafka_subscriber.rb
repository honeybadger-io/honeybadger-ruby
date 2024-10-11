require 'honeybadger/instrumentation_helper'

module Honeybadger
  class KarafkaListener
    include ::Honeybadger::InstrumentationHelper
    include ::Karafka::Core::Configurable
    extend Forwardable

    METRIC_STAT_KEY = {
      increment_counter: :by,
      gauge: :value,
      histogram: :duration
    }

    def_delegators :config, :client, :rd_kafka_metrics, :namespace,
      :default_tags, :distribution_mode

    # Value object for storing a single rdkafka metric publishing details
    RdKafkaMetric = Struct.new(:type, :scope, :name, :key_location)

    # Default tags we want to publish (for example hostname)
    # Format as followed (example for hostname): `["host:#{Socket.gethostname}"]`
    setting :default_tags, default: []

    # All the rdkafka metrics we want to publish
    #
    # By default we publish quite a lot so this can be tuned
    # Note, that the once with `_d` come from Karafka, not rdkafka or Kafka
    setting :rd_kafka_metrics, default: [
      # Client metrics
      RdKafkaMetric.new(:increment_counter, :root, 'messages.consumed', 'rxmsgs_d'),
      RdKafkaMetric.new(:increment_counter, :root, 'messages.consumed.bytes', 'rxmsg_bytes'),

      # Broker metrics
      RdKafkaMetric.new(:increment_counter, :brokers, 'consume.attempts', 'txretries_d'),
      RdKafkaMetric.new(:increment_counter, :brokers, 'consume.errors', 'txerrs_d'),
      RdKafkaMetric.new(:increment_counter, :brokers, 'receive.errors', 'rxerrs_d'),
      RdKafkaMetric.new(:increment_counter, :brokers, 'connection.connects', 'connects_d'),
      RdKafkaMetric.new(:increment_counter, :brokers, 'connection.disconnects', 'disconnects_d'),
      RdKafkaMetric.new(:gauge, :brokers, 'network.latency.avg', %w[rtt avg]),
      RdKafkaMetric.new(:gauge, :brokers, 'network.latency.p95', %w[rtt p95]),
      RdKafkaMetric.new(:gauge, :brokers, 'network.latency.p99', %w[rtt p99]),

      # Topics metrics
      RdKafkaMetric.new(:gauge, :topics, 'consumer.lags', 'consumer_lag_stored'),
      RdKafkaMetric.new(:gauge, :topics, 'consumer.lags_delta', 'consumer_lag_stored_d')
    ].freeze

    configure

    # @param block [Proc] configuration block
    def initialize(&block)
      metric_source("karafka")
      configure
      setup(&block) if block
    end

    # @param block [Proc] configuration block
    # @note We define this alias to be consistent with `WaterDrop#setup`
    def setup(&block)
      configure(&block)
    end

    # Hooks up to Karafka instrumentation for emitted statistics
    #
    # @param event [Karafka::Core::Monitoring::Event]
    def on_statistics_emitted(event)
      statistics = event[:statistics]
      consumer_group_id = event[:consumer_group_id]

      base_tags = default_tags + ["consumer_group:#{consumer_group_id}"]

      rd_kafka_metrics.each do |metric|
        report_metric(metric, statistics, base_tags) if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
      end
    end

    # Increases the errors count by 1
    #
    # @param event [Karafka::Core::Monitoring::Event]
    def on_error_occurred(event)
      extra_tags = ["type:#{event[:type]}"]

      if event.payload[:caller].respond_to?(:messages)
        extra_tags += consumer_tags(event.payload[:caller])
      end

      Honeybadger.notify(event[:error], tags: default_tags + extra_tags)

      if ::Honeybadger.config.load_plugin_insights_events?(:karafka)
        Honeybadger.event("error.occurred.karafka", error: event[:error], tags: default_tags + extra_tags)
      end

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        increment_counter('error_occurred', by: 1, tags: default_tags + extra_tags)
      end
    end

    # Reports how many messages we've polled and how much time did we spend on it
    #
    # @param event [Karafka::Core::Monitoring::Event]
    def on_connection_listener_fetch_loop_received(event)
      time_taken = event[:time]
      messages_count = event[:messages_buffer].size

      consumer_group_id = event[:subscription_group].consumer_group.id

      extra_tags = ["consumer_group:#{consumer_group_id}"]

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        histogram('listener.polling.time_taken', duration: time_taken, tags: default_tags + extra_tags)
        histogram('listener.polling.messages', count: messages_count, tags: default_tags + extra_tags)
      end
    end

    # Here we report majority of things related to processing as we have access to the
    # consumer
    # @param event [Karafka::Core::Monitoring::Event]
    def on_consumer_consumed(event)
      consumer = event.payload[:caller]
      messages = consumer.messages
      metadata = messages.metadata

      tags = default_tags + consumer_tags(consumer)

      if ::Honeybadger.config.load_plugin_insights_events?(:karafka)
        event_context = {
          consumer: consumer.class.name,
          topic: metadata.topic,
          duration: event[:time],
          processing_lag: metadata.processing_lag,
          consumption_lag: metadata.consumption_lag,
          processed: messages.count
        }
        Honeybadger.event("consumer.consumed.karafka", event_context)
      end

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        increment_counter('consumer.messages', by: messages.count, tags: tags)
        increment_counter('consumer.batches', by: 1, tags: tags)
        gauge('consumer.offset', value: metadata.last_offset, tags: tags)
        histogram('consumer.consumed.time_taken', duration: event[:time], tags: tags)
        histogram('consumer.batch_size', count: messages.count, tags: tags)
        histogram('consumer.processing_lag', duration: metadata.processing_lag, tags: tags)
        histogram('consumer.consumption_lag', duration: metadata.consumption_lag, tags: tags)
      end
    end

    {
      revoked: :revoked,
      shutdown: :shutdown,
      ticked: :tick
    }.each do |after, name|
      class_eval <<~RUBY, __FILE__, __LINE__ + 1
              # Keeps track of user code execution
              #
              # @param event [Karafka::Core::Monitoring::Event]
              def on_consumer_#{after}(event)
                tags = default_tags + consumer_tags(event.payload[:caller])

                increment_counter('consumer.#{name}', by: 1, tags: tags)
              end
      RUBY
    end

    # Worker related metrics
    # @param event [Karafka::Core::Monitoring::Event]
    def on_worker_process(event)
      jq_stats = event[:jobs_queue].statistics

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        gauge('worker.total_threads', value: Karafka::App.config.concurrency, tags: default_tags)
        histogram('worker.processing', count: jq_stats[:busy], tags: default_tags)
        histogram('worker.enqueued_jobs', count: jq_stats[:enqueued], tags: default_tags)
      end
    end

    # We report this metric before and after processing for higher accuracy
    # Without this, the utilization would not be fully reflected
    # @param event [Karafka::Core::Monitoring::Event]
    def on_worker_processed(event)
      jq_stats = event[:jobs_queue].statistics

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        histogram('worker.processing', count: jq_stats[:busy], tags: default_tags)
      end
    end

    private

    # Reports a given metric statistics to Honeybadger
    # @param metric [RdKafkaMetric] metric value object
    # @param statistics [Hash] hash with all the statistics emitted
    # @param base_tags [Array<String>] base tags we want to start with
    def report_metric(metric, statistics, base_tags)
      case metric.scope
      when :root
        public_send(
          metric.type,
          metric.name,
          METRIC_STAT_KEY[metric.type] => statistics.fetch(*metric.key_location),
          tags: base_tags
        )
      when :brokers
        statistics.fetch('brokers').each_value do |broker_statistics|
          # Skip bootstrap nodes
          # Bootstrap nodes have nodeid -1, other nodes have positive
          # node ids
          next if broker_statistics['nodeid'] == -1

          public_send(
            metric.type,
            metric.name,
            METRIC_STAT_KEY[metric.type] => broker_statistics.dig(*metric.key_location),
            tags: base_tags + ["broker:#{broker_statistics['nodename']}"]
          )
        end
      when :topics
        statistics.fetch('topics').each do |topic_name, topic_values|
          topic_values['partitions'].each do |partition_name, partition_statistics|
            next if partition_name == '-1'
            # Skip until lag info is available
            next if partition_statistics['consumer_lag'] == -1
            next if partition_statistics['consumer_lag_stored'] == -1

            # Skip if we do not own the fetch assignment
            next if partition_statistics['fetch_state'] == 'stopped'
            next if partition_statistics['fetch_state'] == 'none'

            public_send(
              metric.type,
              metric.name,
              METRIC_STAT_KEY[metric.type] => partition_statistics.dig(*metric.key_location),
              tags: base_tags + [
                "topic:#{topic_name}",
                "partition:#{partition_name}"
              ]
            )
          end
        end
      else
        raise ArgumentError, metric.scope
      end
    end

    # Builds basic per consumer tags for publication
    #
    # @param consumer [Karafka::BaseConsumer]
    # @return [Array<String>]
    def consumer_tags(consumer)
      messages = consumer.messages
      metadata = messages.metadata
      consumer_group_id = consumer.topic.consumer_group.id

      [
        "topic:#{metadata.topic}",
        "partition:#{metadata.partition}",
        "consumer_group:#{consumer_group_id}"
      ]
    end
  end
end
