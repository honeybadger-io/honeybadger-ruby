require "logger"
require "honeybadger/util/sanitizer"

module Honeybadger
  module Breadcrumbs
    # @api private
    #
    module LogHelper
      LOG_SEVERITY_LABELS = {
        ::Logger::DEBUG => "DEBUG",
        ::Logger::INFO => "INFO",
        ::Logger::WARN => "WARN",
        ::Logger::ERROR => "ERROR",
        ::Logger::FATAL => "FATAL",
        ::Logger::UNKNOWN => "ANY"
      }.freeze

      private

      def add_log_breadcrumb(severity, message = nil, progname = nil)
        if defined?(Dry::Logger::Entry) && progname.is_a?(Dry::Logger::Entry) # Hanami uses dry-logger
          message, progname = progname.message || progname.exception, progname.progname
        elsif message.nil?
          message, progname = [progname, nil]
        end
        message &&= Util::Sanitizer.sanitize(message.to_s)&.strip
        unless should_ignore_log?(message, progname)
          Honeybadger.add_breadcrumb(message, category: :log, metadata: {
            severity: log_severity_label(severity),
            progname: progname
          })
        end
      end

      def log_severity_label(severity)
        if self.class.method_defined?(:format_severity) || self.class.private_method_defined?(:format_severity)
          return format_severity(severity)
        end

        LOG_SEVERITY_LABELS.fetch(severity, severity)
      end

      def should_ignore_log?(message, progname)
        message.nil? ||
          message == "" ||
          Thread.current[:__hb_within_log_subscriber] ||
          Thread.current[:__hb_within_broadcast_logger] ||
          progname == "honeybadger"
      end
    end

    module LogWrapper
      include LogHelper

      def add(severity, message = nil, progname = nil, &block)
        org_severity, org_message, org_progname = severity, message, progname
        add_log_breadcrumb(severity, message, progname)

        super(org_severity, org_message, org_progname, &block)
      end
    end

    # @api private
    #
    # ActiveSupport::BroadcastLogger forwards one logical log event to multiple
    # Logger instances. Wrapping it separately records the event once while
    # silencing the sink loggers for the duration of the broadcast.
    module BroadcastLogWrapper
      include LogHelper

      LOG_METHOD_SEVERITIES = {
        debug: ::Logger::DEBUG,
        info: ::Logger::INFO,
        warn: ::Logger::WARN,
        error: ::Logger::ERROR,
        fatal: ::Logger::FATAL,
        unknown: ::Logger::UNKNOWN
      }.freeze

      def add(severity, message = nil, progname = nil, &block)
        add_log_breadcrumb(severity, message, progname)
        without_sink_breadcrumbs { super(severity, message, progname, &block) }
      end
      alias_method :log, :add

      LOG_METHOD_SEVERITIES.each do |level, severity|
        define_method(level) do |progname = nil, &block|
          add_log_breadcrumb(severity, nil, progname)
          without_sink_breadcrumbs { super(progname, &block) }
        end
      end

      private

      def without_sink_breadcrumbs
        previous = Thread.current[:__hb_within_broadcast_logger]
        Thread.current[:__hb_within_broadcast_logger] = true
        yield
      ensure
        Thread.current[:__hb_within_broadcast_logger] = previous
      end
    end

    # @api private
    #
    # This module is designed to be prepended into the
    # ActiveSupport::LogSubscriber for the sole purpose of silencing breadcrumb
    # log events. Since we already have specific breadcrumb events for each
    # class that provides LogSubscriber events, we want to filter out those
    # logs as they just become noise.
    module LogSubscriberInjector
      %w[info debug warn error fatal unknown].each do |level|
        define_method(level) do |*args, &block|
          Thread.current[:__hb_within_log_subscriber] = true
          super(*args, &block)
        ensure
          Thread.current[:__hb_within_log_subscriber] = false
        end
      end
    end
  end
end
