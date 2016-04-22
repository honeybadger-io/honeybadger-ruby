require 'forwardable'
require 'honeybadger/const'

module Honeybadger
  include Forwardable

  extend self

  # Public: Starts the Honeybadger service.
  #
  # opts - The Hash options used to initialize Honeybadger. Accepts config
  #        keys in addition to the listed options. Order of precedence for
  #        config is: 1) ENV, 2) config on disk, 3) opts. (default: {})
  #        :logger - An alternate Logger to use. (optional)
  #
  # Examples:
  #
  #   ENV['HONEYBADGER_API_KEY'] # => 'asdf'
  #
  #   Honeybadger.start # => true
  #
  #   Honeybadger.start({
  #     :root          => ::Rails.root,
  #     :'config.path' => 'config/',
  #     :logger        => Honeybadger::Logging::FormattedLogger.new(::Rails.logger)
  #   }) # => true
  #
  # Returns true if started, otherwise false.
  def start(config = {})
    Agent.start(config)
  end

  # Public: Stops the Honeybadger service.
  #
  # Examples:
  #
  #   Honeybadger.stop # => nil
  #
  # Returns nothing
  def stop
    Agent.stop
  end

  # Public: Send an exception to Honeybadger. Does not report ignored
  # exceptions by default.
  #
  # exception_or_opts - An Exception object, or a Hash of options which is used
  #                     to build the notice.
  # opts              - The options Hash when the first argument is an
  #                     Exception. (default: {}):
  #                     :error_class   - The String class name of the error.
  #                     :error_message - The String error message.
  #                     :force         - Always report the exception (even when
  #                                      ignored).
  #
  # Examples:
  #
  #   # With an exception:
  #   begin
  #     fail 'oops'
  #   rescue => exception
  #     Honeybadger.notify(exception, context: {
  #       my_data: 'value'
  #     }) # => '0dfb92ae-9b01-42e9-9c13-31205b70744a'
  #   end
  #
  #   # Custom notification:
  #   Honeybadger.notify({
  #     error_class: 'MyClass',
  #     error_message: 'Something went wrong.',
  #     context: {my_data: 'value'}
  #   }) # => '06221c5a-b471-41e5-baeb-de247da45a56'
  #
  # Returns a String UUID reference to the notice within Honeybadger or false
  # when ignored.
  def notify(exception_or_opts, opts = {})
    opts.merge!(exception: exception_or_opts) if exception_or_opts.is_a?(Exception)
    opts.merge!(exception_or_opts.to_hash) if exception_or_opts.respond_to?(:to_hash)
    Agent.instance ? Agent.instance.notice(opts) : false
  end

  # Deprecated: Legacy support.
  alias_method :notify_or_ignore, :notify

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
  def exception_filter(&block)
    Agent.exception_filter(&block)
  end

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
  def exception_fingerprint(&block)
    Agent.exception_fingerprint(&block)
  end

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
  def backtrace_filter(&block)
    Agent.backtrace_filter(&block)
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
    unless hash.nil?
      Thread.current[:__honeybadger_context] ||= {}
      Thread.current[:__honeybadger_context].merge!(hash)
    end

    self
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
    Thread.current[:__honeybadger_context]
  end

  # Internal: Clears the global context
  def clear!
    Thread.current[:__honeybadger_context] = nil
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
  #     }.to change(Honeybadger::Backend::Test.notifications[:notices], :size).by(1)
  #   end
  #
  #   # With a block:
  #   it "sends a notification to Honeybadger" do
  #     expect {
  #       Honeybadger.flush do
  #         50.times do
  #           Honeybadger.notify(StandardError.new('test backend'))
  #         end
  #       end
  #     }.to change(Honeybadger::Backend::Test.notifications[:notices], :size).by(50)
  #   end
  #
  # Returns value of block if block is given, otherwise true on success or
  # false if Honeybadger isn't running.
  def flush(&block)
    Agent.flush(&block)
  end

  def configure(*args)
    warn('UPGRADE WARNING: Honeybadger.configure was removed in v2.0 and has no effect. Please upgrade: https://www.honeybadger.io/s/gem-upgrade')
    nil
  end
end

if defined?(::Rails::Railtie)
  require 'honeybadger/init/rails'
elsif defined?(Sinatra::Base)
  require 'honeybadger/init/sinatra'
end

if defined?(Rake.application)
  require 'honeybadger/init/rake'
end
