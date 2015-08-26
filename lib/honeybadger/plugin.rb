require 'forwardable'

module Honeybadger
  class Plugin
    CALLER_FILE = Regexp.new('\A(?:\w:)?([^:]+)(?=(:\d+))').freeze

    class << self
      @@instances = {}

      def instances
        @@instances
      end

      def register(name = nil)
        name ||= name_from_caller(caller) or
          raise(ArgumentError, 'Plugin name is required, but was nil.')
        instances[key = name.to_sym] and fail("Already registered: #{name}")
        instances[key] = new(name).tap { |d| d.instance_eval(&Proc.new) }
      end

      def load!(config)
        instances.each_pair do |name, plugin|
          if config.load_plugin?(name)
            plugin.load!(config)
          else
            config.logger.debug(sprintf('skip plugin name=%s reason=disabled', name))
          end
        end
      end

      def name_from_caller(caller)
        caller && caller[0].match(CALLER_FILE) or
          fail("Unable to determine name from caller: #{caller.inspect}")
        File.basename($1)[/[^\.]+/]
      end
    end

    class Execution
      extend Forwardable

      def initialize(config, &block)
        @config = config
        @block = block
      end

      def call
        instance_eval(&block)
      end

      private

      attr_reader :config, :block
      def_delegator :@config, :logger
    end

    def initialize(name)
      @name         = name
      @loaded       = false
      @requirements = []
      @executions   = []
    end

    def requirement
      @requirements << Proc.new
    end

    def execution
      @executions << Proc.new
    end

    def ok?(config)
      @requirements.all? {|r| Execution.new(config, &r).call }
    rescue => e
      config.logger.error(sprintf("plugin error name=%s class=%s message=%s\n\t%s", name, e.class, e.message.dump, Array(e.backtrace).join("\n\t")))
      false
    end

    def load!(config)
      if @loaded
        config.logger.debug(sprintf('skip plugin name=%s reason=loaded', name))
        return false
      elsif ok?(config)
        config.logger.debug(sprintf('load plugin name=%s', name))
        @executions.each {|e| Execution.new(config, &e).call }
        @loaded = true
      else
        config.logger.debug(sprintf('skip plugin name=%s reason=requirement', name))
      end

      @loaded
    rescue => e
      config.logger.error(sprintf("plugin error name=%s class=%s message=%s\n\t%s", name, e.class, e.message.dump, Array(e.backtrace).join("\n\t")))
      @loaded = true
      false
    end

    # Private: Used for testing only; don't normally call this. :)
    #
    # Returns nothing
    def reset!
      @loaded = false
    end

    def loaded?
      @loaded
    end

    attr_reader :name, :requirements, :executions
  end
end
