require 'json'
require 'securerandom'
require 'forwardable'
require 'ostruct'

require 'honeybadger/version'
require 'honeybadger/backtrace'
require 'honeybadger/util/stats'
require 'honeybadger/util/sanitizer'
require 'honeybadger/rack/request_hash'

module Honeybadger
  NOTIFIER = {
    name: 'honeybadger-ruby'.freeze,
    url: 'https://github.com/honeybadger-io/honeybadger-ruby'.freeze,
    version: VERSION,
    language: 'ruby'.freeze
  }.freeze

  # Internal: Substitution for gem root in backtrace lines.
  GEM_ROOT = '[GEM_ROOT]'.freeze

  # Internal: Substitution for project root in backtrace lines.
  PROJECT_ROOT = '[PROJECT_ROOT]'.freeze

  # Internal: Empty String (used for equality comparisons and assignment)
  STRING_EMPTY = ''.freeze

  # Internal: A Regexp which matches non-blank characters.
  NOT_BLANK = /\S/.freeze

  # Internal: Matches lines beginning with ./
  RELATIVE_ROOT = Regexp.new('^\.\/').freeze

  # Internal: default values to use for request data.
  REQUEST_DEFAULTS = {
    url: nil,
    component: nil,
    action: nil,
    params: {}.freeze,
    session: {}.freeze,
    cgi_data: {}.freeze
  }.freeze

  MAX_EXCEPTION_CAUSES = 5

  class Notice
    extend Forwardable

    # Internal: The String character used to split tag strings.
    TAG_SEPERATOR = ','.freeze

    # Internal: The Regexp used to strip invalid characters from individual tags.
    TAG_SANITIZER = /[^\w]/.freeze

    # Public: The unique ID of this notice which can be used to reference the
    # error in Honeybadger.
    attr_reader :id

    # Public: The exception that caused this notice, if any.
    attr_reader :exception

    # Public: The backtrace from the given exception or hash.
    attr_reader :backtrace

    # Public: Custom fingerprint for error, used to group similar errors together.
    attr_reader :fingerprint

    # Public: Tags which will be applied to error.
    attr_reader :tags

    # Public: The name of the class of error. (example: RuntimeError)
    attr_reader :error_class

    # Public: The message from the exception, or a general description of the error.
    attr_reader :error_message

    # Public: Excerpt from source file.
    attr_reader :source

    # Public: CGI variables such as HTTP_METHOD.
    def_delegator :@request, :cgi_data

    # Public: A hash of parameters from the query string or post body.
    def_delegator :@request, :params
    alias_method :parameters, :params

    # Public: The component (if any) which was used in this request. (usually the controller)
    def_delegator :@request, :component
    alias_method :controller, :component

    # Public: The action (if any) that was called in this request.
    def_delegator :@request, :action

    # Public: A hash of session data from the request.
    def_delegator :@request, :session

    # Public: The URL at which the error occurred (if any).
    def_delegator :@request, :url

    # Public: Local variables are extracted from first frame of backtrace.
    attr_reader :local_variables

    # Internal: Cache project path substitutions for backtrace lines.
    PROJECT_ROOT_CACHE = {}

    # Internal: Cache gem path substitutions for backtrace lines.
    GEM_ROOT_CACHE = {}

    # Internal: A list of backtrace filters to run all the time.
    BACKTRACE_FILTERS = [
      lambda { |line|
        return line unless defined?(Gem)
        GEM_ROOT_CACHE[line] ||= Gem.path.reduce(line) do |line, path|
          line.sub(path, GEM_ROOT)
        end
      },
      lambda { |line, config|
        return line unless config
        c = (PROJECT_ROOT_CACHE[config[:root]] ||= {})
        return c[line] if c.has_key?(line)
        c[line] ||= if config.root_regexp
                      line.sub(config.root_regexp, PROJECT_ROOT)
                    else
                      line
                    end
      },
      lambda { |line| line.sub(RELATIVE_ROOT, STRING_EMPTY) },
      lambda { |line| line if line !~ %r{lib/honeybadger} }
    ].freeze

    def initialize(config, opts = {})
      @now = Time.now.utc
      @pid = Process.pid
      @id = SecureRandom.uuid

      @opts = opts
      @config = config

      @sanitizer = Util::Sanitizer.new
      @filtered_sanitizer = Util::Sanitizer.new(filters: config.params_filters)

      @exception = unwrap_exception(opts[:exception])
      @error_class = exception_attribute(:error_class) {|exception| exception.class.name }
      @error_message = trim_size(1024) do
        exception_attribute(:error_message, 'Notification') do |exception|
          "#{exception.class.name}: #{exception.message}"
        end
      end
      @backtrace = parse_backtrace(exception_attribute(:backtrace, caller))
      @source = extract_source_from_backtrace(@backtrace, config, opts)
      @fingerprint = construct_fingerprint(opts)

      @request = OpenStruct.new(construct_request_hash(config.request, opts, config.excluded_request_keys))

      @context = construct_context_hash(opts)

      @causes = unwrap_causes(@exception)

      @tags = construct_tags(opts[:tags])
      @tags = construct_tags(context[:tags]) | @tags if context

      @stats = Util::Stats.all

      @local_variables = local_variables_from_exception(exception, config)

      @api_key = opts[:api_key] || config[:api_key]

      monkey_patch_action_dispatch_test_process!
    end

    # Internal: Template used to create JSON payload
    #
    # Returns Hash JSON representation of notice
    def as_json(*args)
      {
        api_key: s(api_key),
        notifier: NOTIFIER,
        error: {
          token: id,
          class: s(error_class),
          message: s(error_message),
          backtrace: s(backtrace),
          source: s(source),
          fingerprint: s(fingerprint),
          tags: s(tags),
          causes: s(causes)
        },
        request: {
          url: sanitized_url,
          component: s(component),
          action: s(action),
          params: f(params),
          session: f(session),
          cgi_data: f(cgi_data),
          context: s(context),
          local_variables: s(local_variables)
        },
        server: {
          project_root: s(config[:root]),
          environment_name: s(config[:env]),
          hostname: s(config[:hostname]),
          stats: stats,
          time: now,
          pid: pid
        }
      }
    end

    # Public: Creates JSON
    #
    # Returns valid JSON representation of Notice
    def to_json(*a)
      ::JSON.generate(as_json(*a))
    end

    # Public: Allows properties to be accessed using a hash-like syntax
    #
    # method - The given key for an attribute
    #
    # Examples:
    #
    #   notice[:error_message]
    #
    # Returns the attribute value, or self if given +:request+
    def [](method)
      case method
      when :request
        self
      else
        send(method)
      end
    end

    # Internal: Determines if this notice should be ignored
    def ignore?
      ignore_by_origin? || ignore_by_class? || ignore_by_callbacks?
    end

    private

    attr_reader :config, :opts, :context, :stats, :api_key, :now, :pid, :causes, :sanitizer, :filtered_sanitizer

    def ignore_by_origin?
      opts[:origin] == :rake && !config[:'exceptions.rescue_rake']
    end

    def ignore_by_callbacks?
      opts[:callbacks] &&
        opts[:callbacks].exception_filter &&
        opts[:callbacks].exception_filter.call(self)
    end

    # Gets a property named "attribute" of an exception, either from
    # the #args hash or actual exception (in order of precidence)
    #
    # attribute - A Symbol existing as a key in #args and/or attribute on
    #             Exception
    # default   - Default value if no other value is found. (optional)
    # block     - An optional block which receives an Exception and returns the
    #             desired value
    #
    # Returns attribute value from args or exception, otherwise default
    def exception_attribute(attribute, default = nil, &block)
      opts[attribute] || (exception && from_exception(attribute, &block)) || default
    end

    # Gets a property named +attribute+ from an exception.
    #
    # If a block is given, it will be used when getting the property from an
    # exception. The block should accept and exception and return the value for
    # the property.
    #
    # If no block is given, a method with the same name as +attribute+ will be
    # invoked for the value.
    def from_exception(attribute)
      return unless exception

      if block_given?
        yield(exception)
      else
        exception.send(attribute)
      end
    end

    # Internal: Determines if error class should be ignored
    #
    # ignored_class_name - The name of the ignored class. May be a
    # string or regexp (optional)
    #
    # Returns true or false
    def ignore_by_class?(ignored_class = nil)
      @ignore_by_class ||= Proc.new do |ignored_class|
        case error_class
        when (ignored_class.respond_to?(:name) ? ignored_class.name : ignored_class)
          true
        else
          exception && ignored_class.is_a?(Class) && exception.class < ignored_class
        end
      end

      ignored_class ? @ignore_by_class.call(ignored_class) : config[:'exceptions.ignore'].any?(&@ignore_by_class)
    end

    # Limit size of string to bytes
    #
    # input - The String to be trimmed.
    # bytes - The Integer bytes to trim.
    # block - An optional block used in place of input.
    #
    # Examples
    #
    #   trimmed = trim_size("Honeybadger doesn't care", 3)
    #
    #   trimmed = trim_size(3) do
    #     "Honeybadger doesn't care"
    #   end
    #
    # Returns trimmed String
    def trim_size(*args, &block)
      input, bytes = args.first, args.last
      input = yield if block_given?
      input = input.dup
      input = input[0...bytes] if input.respond_to?(:size) && input.size > bytes
      input
    end

    def construct_backtrace_filters(opts)
      [
        opts[:callbacks] ? opts[:callbacks].backtrace_filter : nil
      ].compact | BACKTRACE_FILTERS
    end

    def construct_request_hash(rack_request, opts, excluded_keys = [])
      request = {}
      request.merge!(Rack::RequestHash.new(rack_request)) if rack_request

      request[:component] = opts[:controller] if opts.has_key?(:controller)
      request[:params] = opts[:parameters] if opts.has_key?(:parameters)

      REQUEST_DEFAULTS.each do |key, default|
        request[key] = opts[key] if opts.has_key?(key)
        request[key] = default if !request[key] || excluded_keys.include?(key)
      end

      request[:session] = request[:session][:data] if request[:session][:data]

      request
    end

    def construct_context_hash(opts)
      context = {}
      context.merge!(Thread.current[:__honeybadger_context]) if Thread.current[:__honeybadger_context]
      context.merge!(opts[:context]) if opts[:context]
      context.empty? ? nil : context
    end

    def extract_source_from_backtrace(backtrace, config, opts)
      return nil if backtrace.lines.empty?

      # ActionView::Template::Error has its own source_extract method.
      # If present, use that instead.
      if exception.respond_to?(:source_extract)
        Hash[exception.source_extract.split("\n").map do |line|
          parts = line.split(': ')
          [parts[0].strip, parts[1] || '']
        end]
      elsif backtrace.application_lines.any?
        backtrace.application_lines.first.source(config[:'exceptions.source_radius'])
      else
        backtrace.lines.first.source(config[:'exceptions.source_radius'])
      end
    end

    def fingerprint_from_opts(opts)
      callback = opts[:fingerprint]
      callback ||= opts[:callbacks] && opts[:callbacks].exception_fingerprint

      if callback.respond_to?(:call)
        callback.call(self)
      else
        callback
      end
    end

    def construct_fingerprint(opts)
      fingerprint = fingerprint_from_opts(opts)
      if fingerprint && fingerprint.respond_to?(:to_s)
        Digest::SHA1.hexdigest(fingerprint.to_s)
      end
    end

    def construct_tags(tags)
      ret = []
      Array(tags).flatten.each do |val|
        val.to_s.split(TAG_SEPERATOR).each do |tag|
          tag.gsub!(TAG_SANITIZER, STRING_EMPTY)
          ret << tag if tag =~ NOT_BLANK
        end
      end

      ret
    end

    def s(data)
      sanitizer.sanitize(data)
    end

    def f(data)
      filtered_sanitizer.sanitize(data)
    end

    def sanitized_url
      return nil unless url
      filtered_sanitizer.filter_url(s(url))
    end

    # Internal: Fetch local variables from first frame of backtrace.
    #
    # exception - The Exception containing the bindings stack.
    #
    # Returns a Hash of local variables
    def local_variables_from_exception(exception, config)
      return {} unless send_local_variables?(config)
      return {} unless Exception === exception
      return {} unless exception.respond_to?(:__honeybadger_bindings_stack)
      return {} if exception.__honeybadger_bindings_stack.empty?

      if config[:root]
        binding = exception.__honeybadger_bindings_stack.find { |b| b.eval('__FILE__') =~ /^#{Regexp.escape(config[:root].to_s)}/ }
      end

      binding ||= exception.__honeybadger_bindings_stack[0]

      vars = binding.eval('local_variables')
      Hash[vars.map {|arg| [arg, binding.eval(arg.to_s)]}]
    end

    # Internal: Should local variables be sent?
    #
    # Returns true to send local_variables
    def send_local_variables?(config)
      config[:'exceptions.local_variables']
    end

    # Internal: Parse Backtrace from exception backtrace.
    #
    # backtrace - The Array backtrace from exception.
    #
    # Returns the Backtrace.
    def parse_backtrace(backtrace)
      Backtrace.parse(
        backtrace,
        filters: construct_backtrace_filters(opts),
        config: config
      )
    end

    # Internal: Unwrap the exception so that original exception is ignored or
    # reported.
    #
    # exception - The exception which was rescued.
    #
    # Returns the Exception to report.
    def unwrap_exception(exception)
      return exception unless config[:'exceptions.unwrap']
      exception_cause(exception) || exception
    end

    # Internal: Fetch cause from exception.
    #
    # exception - Exception to fetch cause from.
    #
    # Returns the Exception cause.
    def exception_cause(exception)
      e = exception
      if e.respond_to?(:cause) && e.cause
        e.cause
      elsif e.respond_to?(:original_exception) && e.original_exception
        e.original_exception
      elsif e.respond_to?(:continued_exception) && e.continued_exception
        e.continued_exception
      end
    end

    # Internal: Unwrap causes from exception.
    #
    # exception - Exception to unwrap.
    #
    # Returns Hash causes (in payload format).
    def unwrap_causes(exception)
      c, e, i = [], exception, 0
      while (e = exception_cause(e)) && i < MAX_EXCEPTION_CAUSES
        c << {
          class: e.class.name,
          message: trim_size(1024) { e.message },
          backtrace: parse_backtrace(e.backtrace || caller)
        }
        i += 1
      end

      c
    end

    # Internal: This is how much Honeybadger cares about Rails developers. :)
    #
    # Some Rails projects include ActionDispatch::TestProcess globally for the
    # use of `fixture_file_upload` in tests. This is a bad practice because it
    # includes other methods -- such as #session -- which override existing
    # methods on *all objects*. This creates the following bug in Notice:
    #
    # When you call #session on any object which had previously defined it
    # (such as OpenStruct), that newly defined method calls #session on
    # @request (defined in `ActionDispatch::TestProcess`), and if @request
    # doesn't exist in that object, it calls #session *again* on `nil`, which
    # also inherited it from Object, resulting in a SystemStackError.
    #
    # This method restores the correct #session method on @request and warns
    # the user of the issue.
    #
    # Returns nothing
    def monkey_patch_action_dispatch_test_process!
      return unless defined?(ActionDispatch::TestProcess) && defined?(self.fixture_file_upload)

      STDOUT.puts('WARNING: It appears you may be including ActionDispatch::TestProcess globally. Check out https://www.honeybadger.io/s/adtp for more info.')

      def @request.session
        @table[:session]
      end

      def self.session
        @request.session
      end
    end
  end
end
