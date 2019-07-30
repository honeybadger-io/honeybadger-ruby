module Honeybadger
  module Breadcrumbs
    # @api private
    #
    module LogWrapper
      def add(severity, message = nil, progname = nil)
        message, progname = [progname, nil] if message.nil?
        message = message && message.to_s.strip
        unless should_ignore_log?(message, progname)
          Honeybadger.add_breadcrumb(message, category: :log, metadata: {
            severity: format_severity(severity),
            progname: progname
          })
        end

        super
      end

      private

      def should_ignore_log?(message, progname)
        message.nil? ||
        message == "" ||
        Thread.current[:__hb_within_log_subscriber] ||
        progname == "honeybadger"
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
      %w(info debug warn error fatal unknown).each do |level|
        define_method(level) do |*args|
          begin
            Thread.current[:__hb_within_log_subscriber] = true
            super(*args)
          ensure
            Thread.current[:__hb_within_log_subscriber] = false
          end
        end
      end
    end
  end
end

