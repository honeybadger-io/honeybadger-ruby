require 'forwardable'
require 'semantic_logger'

module Honeybadger
  # An *external* logger, meant for end users. This is different from the internal logger used by the agent.
  class Logger
    class << self
      extend Forwardable
      def_delegators :appender, *SemanticLogger::Levels::LEVELS, :log

      def appender
        @appender ||= Honeybadger::Logger::Appender.create
      end

      def log_internal_error(error, action:)
        message = sprintf(
          "Honeybadger::Logger error during #{action} class=%s message=%s\n\t%s",
          error.class, error.message.dump, Array(error.backtrace).join("\n\t")
        )
        Honeybadger.config.logger.error(message)
      end
    end

    # The Semantic Logger instance that we use for logging. It receives each log individually via #log,
    # then passes them to the HttpAppender, wrapped in an AsyncBatch
    class Appender < SemanticLogger::Subscriber
      def log(log_entry)
        return false unless should_log?(log_entry)

        batch_appender.log(log_entry)
      rescue => e
        Honeybadger::Logger.log_internal_error(e, action: :log)
      end

      def should_log?(log_entry)
        # Some custom filter, maybe?
        super
      end

      def batch_appender
        return @batch_appender if @batch_appender

        http_appender = HttpAppender.new
        @batch_appender = ::SemanticLogger::Appender.factory(
          appender: http_appender,
          batch: true,
          batch_size: ::Honeybadger.config[:'features.logger.batch_size'],
          batch_seconds: ::Honeybadger.config[:'features.logger.batch_interval'],
        )
        at_exit { shutdown! }
        @batch_appender
      end

      def shutdown!
        @batch_appender.close
        Thread.kill(@batch_appender.thread) if @batch_appender.thread
        @batch_appender.queue.close
      rescue ClosedQueueError
        # Nothing; queue was previously closed
      rescue => e
        Honeybadger::Logger.log_internal_error(e, action: :close)
      end

      def self.create(**args)
        args[:environment] ||= ::Honeybadger.config[:env]
        args[:host] ||= ::Honeybadger.config[:hostname]
        new(**args)
      end
    end

    # HTTP appender for Semantic Logger
    # Semantic logger's AsyncBatch wrapper will handle batching,
    # and call #batch when the batch is ready to be sent
    class HttpAppender < SemanticLogger::Subscriber
      MAX_RETRY_BACKLOG = 200.freeze

      def initialize(*)
        super
        @retry_queue = []
      end

      def default_formatter
        SemanticLogger::Formatters::Json.new
      end

      def batch(logs)
        payload = logs.map { |log| formatter.call(log, self) }.join("\n")
        def payload.to_json; self; end # The Server backend calls to_json
        response = Honeybadger.config.backend.notify(:logs, payload)

        if response.success?
          retry_previous_failed_requests
        else
          @retry_queue << payload
          @retry_queue.shift if @retry_queue.size > MAX_RETRY_BACKLOG
        end
      rescue => e
        Honeybadger::Logger.log_internal_error(e, action: :send)
      end

      private

      def retry_previous_failed_requests
        can_send = true
        until @retry_queue.empty? || !can_send
          payload = @retry_queue.shift
          response = Honeybadger.config.backend.notify(:logs, payload)
          if !response.success?
            @retry_queue.unshift(payload)
            can_send = false
          end
        end
      end
    end
  end
end