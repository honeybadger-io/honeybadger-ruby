require 'honeybadger/instrumentation_helper'

module Honeybadger
  module Karafka
    class ErrorsListener
      # Sends error details to Honeybadger
      #
      # @param event [Karafka::Core::Monitoring::Event]
      def on_error_occurred(event)
        context = {
          type: event[:type]
        }
        tags = ["type:#{event[:type]}"]

        if (consumer = event.payload[:caller]).respond_to?(:messages)
          messages = consumer.messages
          metadata = messages.metadata
          consumer_group_id = consumer.topic.consumer_group.id

          context[:topic] = metadata.topic
          context[:partition] = metadata.partition
          context[:consumer_group] = consumer_group_id
        end

        Honeybadger.notify(event[:error], context: context)
      end
    end

    class InsightsListener
      include ::Honeybadger::InstrumentationHelper

      # Value object for storing a single rdkafka metric publishing details
      RdKafkaMetric = Struct.new(:type, :scope, :name, :key_location)

      # All the rdkafka metrics we want to publish
      #
      # By default we publish quite a lot so this can be tuned
      # Note, that the once with `_d` come from Karafka, not rdkafka or Kafka
      RD_KAFKA_METRICS = [
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
      AGGREGATED_RD_KAFKA_METRICS = [
        # Topic aggregated metrics
        RdKafkaMetric.new(:gauge, :topics, 'consumer_aggregated_lag', 'consumer_lag_stored')
      ].freeze

      def initialize
        metric_source("karafka")
      end

      # Hooks up to Karafka instrumentation for emitted statistics
      #
      # @param event [Karafka::Core::Monitoring::Event]
      def on_statistics_emitted(event)
        if Honeybadger.config.load_plugin_insights_events?(:karafka)
          Honeybadger.event("statistics_emitted.karafka", event.payload)
        end

        return unless Honeybadger.config.load_plugin_insights_metrics?(:karafka)

        statistics = event[:statistics]
        consumer_group_id = event[:consumer_group_id]

        base_tags = { consumer_group: consumer_group_id }

        RD_KAFKA_METRICS.each do |metric|
          report_metric(metric, statistics, base_tags)
        end

        report_aggregated_topics_metrics(statistics, consumer_group_id)
      end

      # Publishes aggregated topic-level metrics that are sum of per partition metrics
      #
      # @param statistics [Hash] hash with all the statistics emitted
      # @param consumer_group_id [String] cg in context which we operate
      def report_aggregated_topics_metrics(statistics, consumer_group_id)
        AGGREGATED_RD_KAFKA_METRICS.each do |metric|
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
              value: sum,
              consumer_group: consumer_group_id,
              topic: topic_name
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

        if Honeybadger.config.load_plugin_insights_events?(:karafka)
          Honeybadger.event("error.occurred.karafka", error: event[:error], **extra_tags)
        end

        if Honeybadger.config.load_plugin_insights_metrics?(:karafka)
          increment_counter('error_occurred', value: 1, **extra_tags)
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

        if Honeybadger.config.load_plugin_insights_metrics?(:karafka)
          histogram('listener_polling_time_taken', value: time_taken, **extra_tags)
          histogram('listener_polling_messages', value: messages_count, **extra_tags)
        end
      end

      # Here we report majority of things related to processing as we have access to the
      # consumer
      # @param event [Karafka::Core::Monitoring::Event]
      def on_consumer_consumed(event)
        consumer = event.payload[:caller]
        messages = consumer.messages
        metadata = messages.metadata

        tags = consumer_tags(consumer)

        if Honeybadger.config.load_plugin_insights_events?(:karafka)
          event_context = tags.merge({
            consumer: consumer.class.name,
            duration: event[:time],
            processing_lag: metadata.processing_lag,
            consumption_lag: metadata.consumption_lag,
            processed: messages.count
          })
          Honeybadger.event("consumer.consumed.karafka", event_context)
        end

        if Honeybadger.config.load_plugin_insights_metrics?(:karafka)
          increment_counter('consumer_messages', value: messages.count, **tags)
          increment_counter('consumer_batches', value: 1, **tags)
          gauge('consumer_offset', value: metadata.last_offset, **tags)
          histogram('consumer_consumed_time_taken', value: event[:time], **tags)
          histogram('consumer_batch_size', value: messages.count, **tags)
          histogram('consumer_processing_lag', value: metadata.processing_lag, **tags)
          histogram('consumer_consumption_lag', value: metadata.consumption_lag, **tags)
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
                if Honeybadger.config.load_plugin_insights_metrics?(:karafka)
                  tags = consumer_tags(event.payload[:caller])
                  increment_counter('consumer_#{name}', value: 1, **tags)
                end
              end
        RUBY
      end

      # Worker related metrics
      # @param event [Karafka::Core::Monitoring::Event]
      def on_worker_process(event)
        jq_stats = event[:jobs_queue].statistics

        if Honeybadger.config.load_plugin_insights_metrics?(:karafka)
          gauge('worker_total_threads', value: ::Karafka::App.config.concurrency)
          histogram('worker_processing', value: jq_stats[:busy])
          histogram('worker_enqueued_jobs', value: jq_stats[:enqueued])
        end
      end

      # We report this metric before and after processing for higher accuracy
      # Without this, the utilization would not be fully reflected
      # @param event [Karafka::Core::Monitoring::Event]
      def on_worker_processed(event)
        jq_stats = event[:jobs_queue].statistics

        if Honeybadger.config.load_plugin_insights_metrics?(:karafka)
          histogram('worker_processing', value: jq_stats[:busy])
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
            value: statistics.fetch(*metric.key_location),
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
              value: broker_statistics.dig(*metric.key_location),
              **base_tags.merge(broker: broker_statistics['nodename'])
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
                value: partition_statistics.dig(*metric.key_location),
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
end
