require 'honeybadger/plugin'
require 'semantic_logger'

module Honeybadger
  module Plugins
    # @api private
    # The Honeybadger semantic_logger plugin. There are two ways to use this:
    # 1. `Honeybadger.logger` is a Semantic Logger appender which sends logs to Honeybadger.
    #    Use it like any other SemanticLogger instance:
    #      Honeybadger.logger.info("Some message", some: :data)
    #      Honeybadger.logger.measure("Fed the dog", duration: 2.minutes)
    # 2. If `config.semantic_logger.enabled` is true, the appender will be automatically added to your SemanticLogger config,
    #    so writing your logs as normal will also send them to Honeybadger.
    #     SemanticLogger["MyApp"].info("Some message", some: :data)
    #     Rails.logger.info("Some message", some: :data)
    # Note that the Rails.logger case requires you to install `rails_semantic_logger`.
    Plugin.register :semantic_logger do
      requirement { config[:'semantic_logger.enabled'] }

      execution do
        next if ::SemanticLogger.appenders.map(&:name).include? Honeybadger::Plugins::HoneybadgerAppender.name

        appender = Honeybadger::Plugins::HoneybadgerAppender.create
        ::SemanticLogger.add_appender(appender: appender)
      end
    end

    class HoneybadgerAppender < SemanticLogger::Appender::Http
      def log(log_details)
        return false unless should_log?(log_details)

        super
      end

      def should_log?(log_details)
        # Some custom filter, maybe?
        super
      end

      HONEYBADGER_LOGS_URL = "http://localhost:4567/log"

      def self.create(**args)
        args[:environment] ||= ::Honeybadger.config[:env]
        args[:host] ||= ::Honeybadger.config[:hostname]
        args = args.merge(
          url: HONEYBADGER_LOGS_URL,
          username: 'honeybadger',
          password: ::Honeybadger. config[:api_key]
        )
        new(**args)
      end
    end
  end
end
