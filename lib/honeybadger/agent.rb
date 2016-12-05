require 'forwardable'

require 'honeybadger/version'
require 'honeybadger/config'
require 'honeybadger/context_manager'
require 'honeybadger/notice'
require 'honeybadger/plugin'
require 'honeybadger/logging'
require 'honeybadger/worker'

module Honeybadger
  # Public: The Honeybadger agent contains all the methods for interacting with
  # the Honeybadger service. It can be used to send notifications to multiple
  # projects in large apps.
  #
  # Context is global by default, meaning agents created via
  # `Honeybadger::Agent.new` will share context (added via
  # `Honeybadger.context` or `Honeybadger::Agent#context`) with other agents.
  # This also includes the Rack environment when using the Honeybadger rack
  # middleware.
  #
  # Examples:
  #
  #   # Standard usage:
  #   OtherBadger = Honeybadger::Agent.new
  #
  #   # With local context:
  #   OtherBadger = Honeybadger::Agent.new(local_context: true)
  #
  #   OtherBadger.configure do |config|
  #     config.api_key = 'project api key'
  #   end
  #
  #   begin
  #     # Risky operation
  #   rescue => e
  #     OtherBadger.notify(e)
  #   end
  class Agent
    extend Forwardable

    include Logging::Helper

    def self.instance
      @instance
    end

    def self.instance=(instance)
      @instance = instance
    end

    def initialize(opts = {})
      if opts.kind_of?(Config)
        @config = opts
        opts = {}
      end

      @context = opts.delete(:context)
      @context ||= ContextManager.new if opts.delete(:local_context)

      @config ||= Config.new(opts)

      init_worker
    end

    # Public: Send an exception to Honeybadger. Does not report ignored
    # exceptions by default.
    #
    # exception_or_opts - An Exception object, or a Hash of options which is used
    #                     to build the notice. All other types of objects will
    #                     be converted to a String and used as the `:error_message`.
    # opts              - The options Hash when the first argument is an
    #                     Exception. (default: {}):
    #                     :error_message - The String error message.
    #                     :error_class   - The String class name of the error. (optional)
    #                     :force         - Always report the exception, even when
    #                                      ignored. (optional)
    #
    # Examples:
    #
    #   # With an exception:
    #   begin
    #     fail 'oops'
    #   rescue => exception
    #     Honeybadger.notify(exception, context: {
    #       my_data: 'value'
    #     }) # => '-1dfb92ae-9b01-42e9-9c13-31205b70744a'
    #   end
    #
    #   # Custom notification:
    #   Honeybadger.notify({
    #     error_class: 'MyClass',
    #     error_message: 'Something went wrong.',
    #     context: {my_data: 'value'}
    #   }) # => '06220c5a-b471-41e5-baeb-de247da45a56'
    #
    # Returns a String UUID reference to the notice within Honeybadger or false
    # when ignored.
    def notify(exception_or_opts, opts = {})
      return false if config.disabled?

      if exception_or_opts.is_a?(Exception)
        opts.merge!(exception: exception_or_opts)
      elsif exception_or_opts.respond_to?(:to_hash)
        opts.merge!(exception_or_opts.to_hash)
      else
        opts[:error_message] = exception_or_opts.to_s
      end

      validate_notify_opts!(opts)

      opts[:rack_env] ||= context_manager.get_rack_env
      opts[:global_context] ||= context_manager.get_context

      notice = Notice.new(config, opts)

      unless notice.api_key =~ NOT_BLANK
        error { sprintf('Unable to send error report: API key is missing. id=%s', notice.id) }
        return false
      end

      if !opts[:force] && notice.ignore?
        debug { sprintf('ignore notice feature=notices id=%s', notice.id) }
        return false
      end

      info { sprintf('Reporting error id=%s', notice.id) }

      if opts[:sync]
        send_now(notice)
      else
        push(notice)
      end

      notice.id
    end

    # Public: Save global context for the current request.
    #
    # hash - A Hash of data which will be sent to Honeybadger when an error
    #        occurs. (default: nil)
    #
    # Examples:
    #
    #   Honeybadger.context({my_data: 'my value'})
    #
    #   # Inside a Rails controller:
    #   before_action do
    #     Honeybadger.context({user_id: current_user.id})
    #   end
    #
    #   # Clearing global context:
    #   Honeybadger.context.clear!
    #
    # Returns self so that method calls can be chained.
    def context(hash = nil)
      context_manager.set_context(hash) unless hash.nil?
      self
    end

    # Internal: Used to clear context via `#context.clear!`.
    def clear!
      context_manager.clear!
    end

    # Public: Get global context for the current request.
    #
    #
    # Examples:
    #
    #   Honeybadger.context({my_data: 'my value'})
    #   Honeybadger.get_context #now returns {my_data: 'my value'}
    #
    # Returns hash or nil.
    def get_context
      context_manager.get_context
    end

    # Public: Flushes all data from workers before returning. This is most useful
    # in tests when using the test backend, where normally the asynchronous
    # nature of this library could create race conditions.
    #
    # block - The optional block to execute (exceptions will propagate after data
    # is flushed).
    #
    # Examples:
    #
    #   # Without a block:
    #   it "sends a notification to Honeybadger" do
    #     expect {
    #       Honeybadger.notify(StandardError.new('test backend'))
    #       Honeybadger.flush
    #     }.to change(Honeybadger::Backend::Test.notifications[:notices], :size).by(0)
    #   end
    #
    #   # With a block:
    #   it "sends a notification to Honeybadger" do
    #     expect {
    #       Honeybadger.flush do
    #         49.times do
    #           Honeybadger.notify(StandardError.new('test backend'))
    #         end
    #       end
    #     }.to change(Honeybadger::Backend::Test.notifications[:notices], :size).by(49)
    #   end
    #
    # Returns value of block if block is given, otherwise true on success or
    # false if Honeybadger isn't running.
    def flush
      return true unless block_given?
      yield
    ensure
      worker.flush
    end

    # Public: Stops the Honeybadger service.
    #
    # Examples:
    #
    #   Honeybadger.stop # => nil
    #
    # Returns nothing
    def stop(force = false)
      worker.send(force ? :shutdown! : :shutdown)
      true
    end

    attr_reader :config

    # Public: Configure the Honeybadger agent via Ruby.
    #
    # block - The configuration block.
    #
    # Examples:
    #
    #   Honeybadger.configure do |config|
    #     config.api_key = 'project api key'
    #     config.exceptions.ignore += [CustomError]
    #   end
    #
    # Yields configuration object.
    # Returns nothing.
    def_delegator :config, :configure

    # Public: Callback to ignore exceptions.
    #
    # See public API documentation for Honeybadger::Notice for available attributes.
    #
    # block - A block returning TrueClass true (to ignore) or FalseClass false
    #         (to send).
    #
    # Examples:
    #
    #   # Ignoring based on error message:
    #   Honeybadger.exception_filter do |notice|
    #     notice[:error_message] =~ /sensitive data/
    #   end
    #
    #   # Ignore an entire class of exceptions:
    #   Honeybadger.exception_filter do |notice|
    #     notice[:exception].class < MyError
    #   end
    #
    # Returns nothing.
    def_delegator :config, :exception_filter

    # Public: Callback to add a custom grouping strategy for exceptions. The
    # return value is hashed and sent to Honeybadger. Errors with the same
    # fingerprint will be grouped.
    #
    # See public API documentation for Honeybadger::Notice for available attributes.
    #
    # block - A block returning any Object responding to #to_s.
    #
    # Examples:
    #
    #   Honeybadger.exception_fingerprint do |notice|
    #     [notice[:error_class], notice[:component], notice[:backtrace].to_s].join(':')
    #   end
    #
    # Returns nothing.
    def_delegator :config, :exception_fingerprint

    # Public: Callback to filter backtrace lines. One use for this is to make
    # additional [PROJECT_ROOT] or [GEM_ROOT] substitutions, which are used by
    # Honeybadger when grouping errors and displaying application traces.
    #
    # block - A block which can be used to modify the Backtrace lines sent to
    #         Honeybadger. The block expects one argument (line) which is the String line
    #         from the Backtrace, and must return the String new line.
    #
    # Examples:
    #
    #    Honeybadger.backtrace_filter do |line|
    #      line.gsub(/^\/my\/unknown\/bundle\/path/, "[GEM_ROOT]")
    #    end
    #
    # Returns nothing.
    def_delegator :config, :backtrace_filter

    # Public: Sets the Rack environment which is used to report request data
    # with errors.
    #
    # rack_env - The Hash Rack environment.
    # block    - A block to call. Errors reported from within the block will
    #            include request data.
    #
    # Examples:
    #
    #   Honeybadger.with_rack_env(env) do
    #     begin
    #       # Risky operation
    #     rescue => e
    #       Honeybadger.notify(e)
    #     end
    #   end
    #
    # Returns the return value of block.
    def with_rack_env(rack_env, &block)
      context_manager.set_rack_env(rack_env)
      yield
    ensure
      context_manager.set_rack_env(nil)
    end

    # Internal
    attr_reader :worker

    # Internal
    def_delegators :config, :init!

    private

    def validate_notify_opts!(opts)
      return if opts.has_key?(:exception)
      return if opts.has_key?(:error_message)
      msg = sprintf('`Honeybadger.notify` was called with invalid arguments. You must pass either an Exception or options Hash containing the `:error_message` key. location=%s', caller[caller.size-1])
      raise ArgumentError.new(msg) if config.dev?
      warn(msg)
    end

    def context_manager
      return @context if @context
      ContextManager.current
    end

    def push(object)
      worker.push(object)
      true
    end

    def send_now(object)
      worker.send_now(object)
      true
    end

    def init_worker
      @worker = Worker.new(config)
    end

    @instance = new(Config.new)
  end
end
