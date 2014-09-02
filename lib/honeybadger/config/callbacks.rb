module Honeybadger
  class Config
    class Callbacks
      attr_reader :backtrace_filter, :exception_filter, :exception_fingerprint

      def initialize
        @backtrace_filter = nil
        @exception_filter = nil
        @exception_fingerprint = nil
      end

      # Public: Takes a block and adds it to the list of backtrace filters. When
      # the filters run, the block will be handed each line of the backtrace and
      # can modify it as necessary.
      #
      # &block - The new backtrace filter.
      #
      # Examples:
      #
      #    config.backtrace_filter do |line|
      #      line.gsub(/^#{Rails.root}/, "[Rails.root]")
      #    end
      #
      # Yields a line in the backtrace.
      def backtrace_filter(&block)
        @backtrace_filter = Proc.new if block_given?
        @backtrace_filter
      end

      # Public: Takes a block and adds it to the list of ignore filters. When
      # the filters run, the block will be handed the exception.
      #
      # &block - The new ignore filter
      #          If the block returns true the exception will be ignored, otherwise it
      #          will be processed by honeybadger.
      #
      # Examples:
      #
      #   config.exception_filter do |exception|
      #     if exception.class < MyError
      #       nil
      #     else
      #       exception
      #     end
      #   end
      #
      # Yields the the exception data given to Honeybadger.notify
      def exception_filter(&block)
        @exception_filter = Proc.new if block_given?
        @exception_filter
      end

      # Public: Generate custom fingerprint (optional)
      #
      # block - An optional block returning object responding to #to_s
      #
      # Examples
      #
      #   config.exception_fingerprint do |notice|
      #     [notice[:error_class], notice[:component], notice[:backtrace].to_s].join(':')
      #   end
      #
      # Returns configured fingerprint generator (should respond to #call(notice))
      def exception_fingerprint
        @exception_fingerprint = Proc.new if block_given?
        @exception_fingerprint
      end
    end
  end
end
