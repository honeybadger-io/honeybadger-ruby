require 'honeybadger/instrumentation_helper'

module Honeybadger
  class KarafkaSubscriber
    include ::Honeybadger::InstrumentationHelper
    include ::Karafka::Core::Configurable
    extend Forwardable

    METRIC_STAT_KEY = {
      increment_counter: :by,
      gauge: :value,
      histogram: :duration
    }

    def_delegators :config, :rd_kafka_metrics, :aggregated_rd_kafka_metrics, :default_tags, :source

    # Value object for storing a single rdkafka metric publishing details
    RdKafkaMetric = Struct.new(:type, :scope, :name, :key_location)

    setting :source, default: 'karafka'

    # Default tags we want to publish (for example hostname)
    # Format as followed (example for hostname): `["host:#{Socket.gethostname}"]`
    setting :default_tags, default: {}

    # All the rdkafka metrics we want to publish
    #
    # By default we publish quite a lot so this can be tuned
    # Note, that the once with `_d` come from Karafka, not rdkafka or Kafka
    setting :rd_kafka_metrics, default: [
      # Client metrics
      RdKafkaMetric.new(:increment_counter, :root, 'messages_consumed', 'rxmsgs_d'),
      RdKafkaMetric.new(:increment_counter, :root, 'messages_consumed_bytes', 'rxmsg_bytes'),

      # Broker metrics
      RdKafkaMetric.new(:increment_counter, :brokers, 'consume_attempts', 'txretries_d'),
      RdKafkaMetric.new(:increment_counter, :brokers, 'consume_errors', 'txerrs_d'),
      RdKafkaMetric.new(:increment_counter, :brokers, 'receive_errors', 'rxerrs_d'),
      RdKafkaMetric.new(:increment_counter, :brokers, 'connection_connects', 'connects_d'),
      RdKafkaMetric.new(:increment_counter, :brokers, 'connection_disconnects', 'disconnects_d'),
      RdKafkaMetric.new(:gauge, :brokers, 'network_latency_avg', %w[rtt avg]),
      RdKafkaMetric.new(:gauge, :brokers, 'network_latency_p95', %w[rtt p95]),
      RdKafkaMetric.new(:gauge, :brokers, 'network_latency_p99', %w[rtt p99]),

      # Topics metrics
      RdKafkaMetric.new(:gauge, :topics, 'consumer_lags', 'consumer_lag_stored'),
      RdKafkaMetric.new(:gauge, :topics, 'consumer_lags_delta', 'consumer_lag_stored_d')
    ].freeze

    # Metrics that sum values on topics levels and not on partition levels
    setting :aggregated_rd_kafka_metrics, default: [
      # Topic aggregated metrics
      RdKafkaMetric.new(:gauge, :topics, 'consumer_aggregated_lag', 'consumer_lag_stored')
    ].freeze

    configure

    # @param block [Proc] configuration block
    def initialize(&block)
      metric_source(source)
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
      return unless ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)

      statistics = event[:statistics]
      consumer_group_id = event[:consumer_group_id]

      base_tags = default_tags.merge(consumer_group: consumer_group_id)

      config.rd_kafka_metrics.each do |metric|
        report_metric(metric, statistics, base_tags)
      end

      report_aggregated_topics_metrics(statistics, consumer_group_id)
    end

    # Publishes aggregated topic-level metrics that are sum of per partition metrics
    #
    # @param statistics [Hash] hash with all the statistics emitted
    # @param consumer_group_id [String] cg in context which we operate
    def report_aggregated_topics_metrics(statistics, consumer_group_id)
      config.aggregated_rd_kafka_metrics.each do |metric|
        statistics.fetch('topics').each do |topic_name, topic_values|
          sum = 0

          topic_values['partitions'].each do |partition_name, partition_statistics|
            next if partition_name == '-1'
            # Skip until lag info is available
            next if partition_statistics['consumer_lag'] == -1
            next if partition_statistics['consumer_lag_stored'] == -1

            sum += partition_statistics.dig(*metric.key_location)
          end

          public_send(
            metric.type,
            metric.name,
            METRIC_STAT_KEY[metric.type] => sum,
            **default_tags.merge({
              consumer_group: consumer_group_id,
              topic: topic_name
            })
          )
        end
      end
    end

    # Increases the errors count by 1
    #
    # @param event [Karafka::Core::Monitoring::Event]
    def on_error_occurred(event)
      extra_tags = { type: event[:type] }

      if event.payload[:caller].respond_to?(:messages)
        extra_tags.merge!(consumer_tags(event.payload[:caller]))
      end

      if ::Honeybadger.config.load_plugin_insights_events?(:karafka)
        Honeybadger.event("error.occurred.karafka", error: event[:error], **default_tags.merge(extra_tags))
      end

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        increment_counter('error_occurred', by: 1, **default_tags.merge(extra_tags))
      end
    end

    # Reports how many messages we've polled and how much time did we spend on it
    #
    # @param event [Karafka::Core::Monitoring::Event]
    def on_connection_listener_fetch_loop_received(event)
      time_taken = event[:time]
      messages_count = event[:messages_buffer].size

      consumer_group_id = event[:subscription_group].consumer_group.id

      extra_tags = { consumer_group: consumer_group_id }

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        histogram('listener_polling_time_taken', duration: time_taken, **default_tags.merge(extra_tags))
        histogram('listener_polling_messages', count: messages_count, **default_tags.merge(extra_tags))
      end
    end

    # Here we report majority of things related to processing as we have access to the
    # consumer
    # @param event [Karafka::Core::Monitoring::Event]
    def on_consumer_consumed(event)
      consumer = event.payload[:caller]
      messages = consumer.messages
      metadata = messages.metadata

      tags = default_tags.merge(consumer_tags(consumer))

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
        increment_counter('consumer_messages', by: messages.count, **tags)
        increment_counter('consumer_batches', by: 1, **tags)
        gauge('consumer_offset', value: metadata.last_offset, **tags)
        histogram('consumer_consumed_time_taken', duration: event[:time], **tags)
        histogram('consumer_batch_size', count: messages.count, **tags)
        histogram('consumer_processing_lag', duration: metadata.processing_lag, **tags)
        histogram('consumer_consumption_lag', duration: metadata.consumption_lag, **tags)
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
                tags = default_tags.merge(consumer_tags(event.payload[:caller]))

                increment_counter('consumer_#{name}', by: 1, **tags)
              end
      RUBY
    end

    # Worker related metrics
    # @param event [Karafka::Core::Monitoring::Event]
    def on_worker_process(event)
      jq_stats = event[:jobs_queue].statistics

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        gauge('worker_total_threads', value: Karafka::App.config.concurrency, **default_tags)
        histogram('worker_processing', count: jq_stats[:busy], **default_tags)
        histogram('worker_enqueued_jobs', count: jq_stats[:enqueued], **default_tags)
      end
    end

    # We report this metric before and after processing for higher accuracy
    # Without this, the utilization would not be fully reflected
    # @param event [Karafka::Core::Monitoring::Event]
    def on_worker_processed(event)
      jq_stats = event[:jobs_queue].statistics

      if ::Honeybadger.config.load_plugin_insights_metrics?(:karafka)
        histogram('worker_processing', count: jq_stats[:busy], **default_tags)
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
          **base_tags
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
            **base_tags.merge({ broker: broker_statistics['nodename'] })
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
              **base_tags.merge({
                topic: topic_name,
                partition: partition_name
              })
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

      {
        topic: metadata.topic,
        partition: metadata.partition,
        consumer_group: consumer_group_id
      }
    end
  end
end
