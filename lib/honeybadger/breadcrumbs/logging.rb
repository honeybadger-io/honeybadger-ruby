module Honeybadger
  module Breadcrumbs
    module LogWrapper
      def add(severity, message = nil, progname = nil)
        message, progname = [progname, nil] if message.nil?
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

    module LogSubscriberInjector
      %w(info debug warn error fatal unknown).each do |level|
        define_method(level) do |*args|
          Thread.current[:__hb_within_log_subscriber] = true
          super(*args)
        ensure
          Thread.current[:__hb_within_log_subscriber] = false
        end
      end
    end
  end
end

