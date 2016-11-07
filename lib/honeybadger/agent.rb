require 'forwardable'

require 'honeybadger/version'
require 'honeybadger/config'
require 'honeybadger/context_manager'
require 'honeybadger/notice'
require 'honeybadger/plugin'
require 'honeybadger/logging'
require 'honeybadger/agent/worker'
require 'honeybadger/agent/null_worker'

module Honeybadger
  # Internal: A broker for the configuration and the worker.
  class Agent
    extend Forwardable

    include Logging::Helper

    def self.load_plugins!
      Dir[File.expand_path('../plugins/*.rb', __FILE__)].each do |plugin|
        require plugin
      end
      Plugin.load!(self.config)
    end

    def self.instance
      @instance
    end

    def self.instance=(instance)
      @instance = instance
    end

    # Deprecated
    def self.running?
      true
    end

    # Deprecated
    def self.start(config = {})
      true
    end

    class << self
      extend Forwardable

      def_delegators :instance, :config, :notify, :context, :get_context, :flush, :stop
      def_delegators :config, :configure, :exception_filter, :exception_fingerprint, :backtrace_filter
    end

    def initialize(config = nil)
      @config = config if config.kind_of?(Config)
      @config = Config.new(config) if config.kind_of?(Hash)
      @config ||= Config.new

      @context_manager = ContextManager.current

      init_worker
    end

    attr_reader :worker

    attr_reader :config
    def_delegators :config, :init!, :configure
    def_delegators :config, :exception_filter, :exception_fingerprint, :backtrace_filter

    def notify(exception_or_opts, opts = {})
      return false if config.disabled?

      opts.merge!(exception: exception_or_opts) if exception_or_opts.is_a?(Exception)
      opts.merge!(exception_or_opts.to_hash) if exception_or_opts.respond_to?(:to_hash)
      opts.merge!(rack_env: context_manager.get_rack_env)
      opts.merge!(global_context: context_manager.get_context)

      notice = Notice.new(config, opts)

      unless notice.api_key =~ NOT_BLANK
        error { sprintf('Unable to send error report: API key is missing. id=%s', notice.id) }
        return false
      end

      if !opts[:force] && notice.ignore?
        debug { sprintf('ignore notice feature=notices id=%s', notice.id) }
        false
      else
        debug { sprintf('notice feature=notices id=%s', notice.id) }
        if opts[:sync]
          config.backend.notify(:notices, notice)
        else
          push(notice)
        end
        notice.id
      end
    end

    def context(hash = nil)
      context_manager.set_context(hash) unless hash.nil?
      self
    end

    def get_context
      context_manager.get_context
    end

    def clear!
      context_manager.clear!
    end

    # Public: Flush the worker. See Honeybadger#flush.
    #
    # block - an option block which is executed before flushing data.
    #
    # Returns value from block if block is given, otherwise true.
    def flush
      return true unless block_given?
      yield
    ensure
      worker.flush
    end

    def stop(force = false)
      worker.send(force ? :shutdown! : :shutdown)
      true
    end

    def with_rack_env(rack_env, &block)
      context_manager.set_rack_env(rack_env)
      yield
    ensure
      context_manager.set_rack_env(nil)
    end

    private

    attr_reader :context_manager

    def push(object)
      worker.push(object)
      true
    end

    def init_worker
      @worker = Worker.new(config, :notices)
    end

    @instance = new(Config.new)
  end
end
