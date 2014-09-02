require 'logger'
require 'singleton'
require 'delegate'

module Honeybadger
  module Logging
    PREFIX = '** [Honeybadger] '.freeze

    module Helper
      def debug(msg = nil)
        return if Logger::Severity::DEBUG < logger.level
        msg = yield if block_given?
        logger.debug(msg)
      end

      def info(msg = nil)
        return if Logger::Severity::INFO < logger.level
        msg = yield if block_given?
        logger.info(msg)
      end

      def warn(msg = nil)
        return if Logger::Severity::WARN < logger.level
        msg = yield if block_given?
        logger.warn(msg)
      end

      def error(msg = nil)
        return if Logger::Severity::ERROR < logger.level
        msg = yield if block_given?
        logger.error(msg)
      end

      def logger
        @config.logger
      end
    end

    class Base
      Logger::Severity.constants.each do |severity|
        define_method severity.downcase do |msg|
          add(Logger::Severity.const_get(severity), msg)
        end
      end

      def add(severity, message)
        raise NotImplementedError, 'must define #add on subclass.'
      end

      def level
        Logger::Severity::Debug
      end
    end

    class FormattedLogger < Base
      def initialize(logger = Logger.new('/dev/null'))
        raise ArgumentError, 'logger not specified' unless logger
        raise ArgumentError, 'logger must be a logger' unless logger.respond_to?(:add)

        @logger = logger
      end

      def add(severity, message)
        @logger.add(severity, format_message(message))
      end

      def level
        @logger.level
      end

      private

      def format_message(message)
        return message unless message.kind_of?(String)
        PREFIX + message
      end
    end

    class BootLogger < Base
      include Singleton

      def initialize
        @messages = []
      end

      def add(severity, message)
        @messages << [severity, message]
      end

      def flush(logger)
        @messages.each do |msg|
          logger.add(*msg)
        end
        @messages.clear
      end
    end

    class SupplementedLogger < SimpleDelegator
      LOCATE_CALLER_LOCATION = Regexp.new("#{Regexp.escape(__FILE__)}").freeze
      CALLER_LOCATION = Regexp.new("#{Regexp.escape(File.expand_path('../../../', __FILE__))}/(.*)").freeze

      INFO_SUPPLEMENT = ' level=%s pid=%s'.freeze
      DEBUG_SUPPLEMENT = ' at=%s'.freeze

      def initialize(logger = Logger.new('/dev/null'))
        raise ArgumentError, 'logger not specified' unless logger
        super
      end

      Logger::Severity.constants.each do |severity|
        define_method l = severity.downcase do |msg|
          __getobj__().send(l, supplement(msg, l))
        end
      end

      private

      def supplement(msg, level)
        msg << sprintf(INFO_SUPPLEMENT, level, Process.pid)
        if level == :debug && l = caller_location
          msg << sprintf(DEBUG_SUPPLEMENT, l.dump)
        end
        msg
      end

      def caller_location
        if caller && caller.find {|l| l !~ LOCATE_CALLER_LOCATION && l =~ CALLER_LOCATION }
          Regexp.last_match(1)
        end
      end
    end
  end
end
