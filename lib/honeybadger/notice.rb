require 'json'
require 'securerandom'
require 'forwardable'
require 'ostruct'

require 'honeybadger/version'
require 'honeybadger/backtrace'
require 'honeybadger/util/stats'
require 'honeybadger/util/sanitizer'
require 'honeybadger/util/request_sanitizer'
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
        c[line] ||= if (root = config[:root].to_s) != STRING_EMPTY
                      line.sub(root, PROJECT_ROOT)
                    else
                      line
                    end
      },
      lambda { |line| line.sub(RELATIVE_ROOT, STRING_EMPTY) },
      lambda { |line| line if line !~ %r{lib/honeybadger} }
    ].freeze

    def initialize(config, opts = {})
      @now = Time.now.utc
      @id = SecureRandom.uuid

      @opts = opts
      @config = config

      @exception = opts[:exception]
      @error_class = exception_attribute(:error_class) {|exception| exception.class.name }
      @error_message = trim_size(1024) do
        exception_attribute(:error_message, 'Notification') do |exception|
          "#{exception.class.name}: #{exception.message}"
        end
      end
      @backtrace = Backtrace.parse(
        exception_attribute(:backtrace, caller),
        filters: construct_backtrace_filters(opts),
        config: config
      )
      @source = extract_source_from_backtrace(@backtrace, config, opts)
      @fingerprint = construct_fingerprint(opts)

      @sanitizer = Util::Sanitizer.new(filters: config.params_filters)
      @request_sanitizer = Util::RequestSanitizer.new(@sanitizer)
      @request = OpenStruct.new(construct_request_hash(config.request, opts, @request_sanitizer, config.excluded_request_keys))
      @context = construct_context_hash(opts, @sanitizer)

      @tags = construct_tags(opts[:tags])
      @tags = construct_tags(context[:tags]) | @tags if context

      @stats = Util::Stats.all

      @local_variables = send_local_variables?(config) ? local_variables_from_exception(exception, config) : {}

      @api_key = opts[:api_key] || config[:api_key]
    end

    # Internal: Template used to create JSON payload
    #
    # Returns Hash JSON representation of notice
    def as_json(*args)
      {
        api_key: api_key,
        notifier: NOTIFIER,
        error: {
          token: id,
          class: error_class,
          message: error_message,
          backtrace: backtrace,
          source: source,
          fingerprint: fingerprint,
          tags: tags
        },
        request: {
          url: url,
          component: component,
          action: action,
          params: params,
          session: session,
          cgi_data: cgi_data,
          context: context,
          local_variables: local_variables
        },
        server: {
          project_root: config[:root],
          environment_name: config[:env],
          hostname: config[:hostname],
          stats: stats,
          time: now
        }
      }
    end

    # Public: Creates JSON
    #
    # Returns valid JSON representation of Notice
    def to_json(*a)
      as_json.to_json(*a)
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

    attr_reader :config, :opts, :context, :stats, :api_key, :now

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
      opts[attribute] || (opts[:exception] && from_exception(attribute, &block)) || default
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
      return unless opts[:exception]

      if block_given?
        yield(opts[:exception])
      else
        opts[:exception].send(attribute)
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

    def construct_request_hash(rack_request, opts, sanitizer, excluded_keys = [])
      request = {}
      request.merge!(Rack::RequestHash.new(rack_request)) if rack_request

      request[:component] = opts[:controller] if opts.has_key?(:controller)
      request[:params] = opts[:parameters] if opts.has_key?(:parameters)

      REQUEST_DEFAULTS.each do |key, default|
        request[key] = opts[key] if opts.has_key?(key)
        request[key] = default if !request[key] || excluded_keys.include?(key)
      end

      request[:session] = request[:session][:data] if request[:session][:data]

      sanitizer.sanitize(request)
    end

    def construct_context_hash(opts, sanitizer)
      context = {}
      context.merge!(Thread.current[:__honeybadger_context]) if Thread.current[:__honeybadger_context]
      context.merge!(opts[:context]) if opts[:context]
      context.empty? ? nil : sanitizer.sanitize(context)
    end

    def extract_source_from_backtrace(backtrace, config, opts)
      if backtrace.lines.empty?
        nil
      else
        # ActionView::Template::Error has its own source_extract method.
        # If present, use that instead.
        if opts[:exception].respond_to?(:source_extract)
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

    # Internal: Fetch local variables from first frame of backtrace.
    #
    # exception - The Exception containing the bindings stack.
    #
    # Returns a Hash of local variables
    def local_variables_from_exception(exception, config)
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
  end
end
