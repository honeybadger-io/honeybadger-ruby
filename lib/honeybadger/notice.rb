require 'json'
require 'securerandom'
require 'forwardable'

require 'honeybadger/version'
require 'honeybadger/backtrace'
require 'honeybadger/conversions'
require 'honeybadger/util/stats'
require 'honeybadger/util/sanitizer'
require 'honeybadger/util/request_hash'
require 'honeybadger/util/request_payload'

module Honeybadger
  # @api private
  NOTIFIER = {
    name: 'honeybadger-ruby'.freeze,
    url: 'https://github.com/honeybadger-io/honeybadger-ruby'.freeze,
    version: VERSION,
    language: 'ruby'.freeze
  }.freeze

  # @api private
  # Substitution for gem root in backtrace lines.
  GEM_ROOT = '[GEM_ROOT]'.freeze

  # @api private
  # Substitution for project root in backtrace lines.
  PROJECT_ROOT = '[PROJECT_ROOT]'.freeze

  # @api private
  # Empty String (used for equality comparisons and assignment).
  STRING_EMPTY = ''.freeze

  # @api private
  # A Regexp which matches non-blank characters.
  NOT_BLANK = /\S/.freeze

  # @api private
  # Matches lines beginning with ./
  RELATIVE_ROOT = Regexp.new('^\.\/').freeze

  # @api private
  MAX_EXCEPTION_CAUSES = 5

  class Notice
    extend Forwardable

    include Conversions

    # @api private
    # The String character used to split tag strings.
    TAG_SEPERATOR = ','.freeze

    # @api private
    # The Regexp used to strip invalid characters from individual tags.
    TAG_SANITIZER = /[^\w]/.freeze

    # The unique ID of this notice which can be used to reference the error in
    # Honeybadger.
    attr_reader :id

    # The exception that caused this notice, if any.
    attr_reader :exception

    # The exception cause if available.
    attr_reader :cause

    # The backtrace from the given exception or hash.
    attr_reader :backtrace

    # Custom fingerprint for error, used to group similar errors together.
    attr_reader :fingerprint

    # Tags which will be applied to error.
    attr_reader :tags

    # The name of the class of error (example: RuntimeError).
    attr_reader :error_class

    # The message from the exception, or a general description of the error.
    attr_reader :error_message

    # Deprecated: Excerpt from source file.
    attr_reader :source

    # CGI variables such as HTTP_METHOD.
    def cgi_data; @request[:cgi_data]; end

    # A hash of parameters from the query string or post body.
    def params; @request[:params]; end
    alias_method :parameters, :params

    # The component (if any) which was used in this request (usually the controller).
    def component; @request[:component]; end
    alias_method :controller, :component

    # The action (if any) that was called in this request.
    def action; @request[:action]; end

    # A hash of session data from the request.
    def_delegator :@request, :session
    def session; @request[:session]; end

    # The URL at which the error occurred (if any).
    def url; @request[:url]; end

    # Local variables are extracted from first frame of backtrace.
    attr_reader :local_variables

    # Public: The API key used to deliver this notice.
    attr_accessor :api_key

    # @api private
    # Cache project path substitutions for backtrace lines.
    PROJECT_ROOT_CACHE = {}

    # @api private
    # Cache gem path substitutions for backtrace lines.
    GEM_ROOT_CACHE = {}

    # @api private
    # A list of backtrace filters to run all the time.
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

    # @api private
    def initialize(config, opts = {})
      @now = Time.now.utc
      @pid = Process.pid
      @id = SecureRandom.uuid

      @opts = opts
      @config = config

      @rack_env = opts.fetch(:rack_env, nil)

      @request_sanitizer = Util::Sanitizer.new(filters: params_filters)

      @exception = unwrap_exception(opts[:exception])
      @error_class = exception_attribute(:error_class, 'Notice') {|exception| exception.class.name }
      @error_message = exception_attribute(:error_message, 'No message provided') do |exception|
        "#{exception.class.name}: #{exception.message}"
      end
      @backtrace = parse_backtrace(exception_attribute(:backtrace, caller))

      @request = construct_request_hash(config, opts)

      @context = construct_context_hash(opts, exception)

      @cause = opts[:cause] || exception_cause(@exception) || $!
      @causes = unwrap_causes(@cause)

      @tags = construct_tags(opts[:tags])
      @tags = construct_tags(context[:tags]) | @tags if context

      @stats = Util::Stats.all

      @local_variables = local_variables_from_exception(exception, config)

      @api_key = opts[:api_key] || config[:api_key]

      monkey_patch_action_dispatch_test_process!

      # Fingerprint must be calculated last since callback operates on `self`.
      @fingerprint = construct_fingerprint(opts)
    end

    # @api private
    # Template used to create JSON payload.
    #
    # @return [Hash] JSON representation of notice.
    def as_json(*args)
      @request[:context] = s(context)
      @request[:local_variables] = local_variables if local_variables

      {
        api_key: s(api_key),
        notifier: NOTIFIER,
        error: {
          token: id,
          class: s(error_class),
          message: s(error_message),
          backtrace: s(backtrace.to_a),
          fingerprint: s(fingerprint),
          tags: s(tags),
          causes: s(causes)
        },
        request: @request,
        server: {
          project_root: s(config[:root]),
          revision: s(config[:revision]),
          environment_name: s(config[:env]),
          hostname: s(config[:hostname]),
          stats: stats,
          time: now,
          pid: pid
        }
      }
    end

    # Converts the notice to JSON.
    #
    # @return [Hash] The JSON representation of the notice.
    def to_json(*a)
      ::JSON.generate(as_json(*a))
    end

    # Allows properties to be accessed using a hash-like syntax.
    #
    # @example
    #   notice[:error_message]
    #
    # @param [Symbol] method The given key for an attribute.
    #
    # @return [Object] The attribute value.
    def [](method)
      case method
      when :request
        self
      else
        send(method)
      end
    end

    # @api private
    # Determines if this notice should be ignored.
    def ignore?
      ignore_by_origin? || ignore_by_class? || ignore_by_callbacks?
    end

    private

    attr_reader :config, :opts, :context, :stats, :now, :pid, :causes,
      :request_sanitizer, :rack_env

    def ignore_by_origin?
      return false if opts[:origin] != :rake
      return false if config[:'exceptions.rescue_rake']
      true
    end

    def ignore_by_callbacks?
      config.exception_filter &&
        config.exception_filter.call(self)
    end

    # Gets a property named "attribute" of an exception, either from
    # the #args hash or actual exception (in order of precidence).
    #
    # attribute - A Symbol existing as a key in #args and/or attribute on
    #             Exception.
    # default   - Default value if no other value is found (optional).
    # block     - An optional block which receives an Exception and returns the
    #             desired value.
    #
    # Returns attribute value from args or exception, otherwise default.
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

    # Determines if error class should be ignored.
    #
    # ignored_class_name - The name of the ignored class. May be a
    # string or regexp (optional).
    #
    # Returns true or false.
    def ignore_by_class?(ignored_class = nil)
      @ignore_by_class ||= Proc.new do |ignored_class|
        case error_class
        when (ignored_class.respond_to?(:name) ? ignored_class.name : ignored_class)
          true
        else
          exception && ignored_class.is_a?(Class) && exception.class < ignored_class
        end
      end

      ignored_class ? @ignore_by_class.call(ignored_class) : config.ignored_classes.any?(&@ignore_by_class)
    end

    def construct_backtrace_filters(opts)
      [
        config.backtrace_filter
      ].compact | BACKTRACE_FILTERS
    end

    def request_hash
      return {} unless rack_env
      Util::RequestHash.from_env(rack_env)
    end

    # Construct the request object with data from various sources.
    #
    # Returns Request.
    def construct_request_hash(config, opts)
      request = {}
      request.merge!(request_hash)
      request.merge!(opts)
      request[:component] = opts[:controller] if opts.has_key?(:controller)
      request[:params] = opts[:parameters] if opts.has_key?(:parameters)
      request.delete_if {|k,v| config.excluded_request_keys.include?(k) }
      request[:sanitizer] = request_sanitizer
      Util::RequestPayload.build(request)
    end

    # Get optional context from exception.
    #
    # Returns the Hash context.
    def exception_context(exception)
      # This extra check exists because the exception itself is not expected to
      # convert to a hash.
      object = exception if exception.respond_to?(:to_honeybadger_context)
      object ||= {}.freeze

      Context(object)
    end

    def construct_context_hash(opts, exception)
      context = {}
      context.merge!(Context(opts[:global_context]))
      context.merge!(exception_context(exception))
      context.merge!(Context(opts[:context]))
      context.empty? ? nil : context
    end

    def fingerprint_from_opts(opts)
      callback = opts[:fingerprint]
      callback ||= config.exception_fingerprint

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
      Util::Sanitizer.sanitize(data)
    end

    # Fetch local variables from first frame of backtrace.
    #
    # exception - The Exception containing the bindings stack.
    #
    # Returns a Hash of local variables.
    def local_variables_from_exception(exception, config)
      return nil unless send_local_variables?(config)
      return {} unless Exception === exception
      return {} unless exception.respond_to?(:__honeybadger_bindings_stack)
      return {} if exception.__honeybadger_bindings_stack.empty?

      if config[:root]
        binding = exception.__honeybadger_bindings_stack.find { |b| b.eval('__FILE__') =~ /^#{Regexp.escape(config[:root].to_s)}/ }
      end

      binding ||= exception.__honeybadger_bindings_stack[0]

      vars = binding.eval('local_variables')
      results =
        vars.inject([]) { |acc, arg|
          begin
            result = binding.eval(arg.to_s)
            acc << [arg, result]
          rescue NameError
            # Do Nothing
          end

          acc
        }

      result_hash = Hash[results]
      request_sanitizer.sanitize(result_hash)
    end

    # Should local variables be sent?
    #
    # Returns true to send local_variables.
    def send_local_variables?(config)
      config[:'exceptions.local_variables']
    end

    # Parse Backtrace from exception backtrace.
    #
    # backtrace - The Array backtrace from exception.
    #
    # Returns the Backtrace.
    def parse_backtrace(backtrace)
      Backtrace.parse(
        backtrace,
        filters: construct_backtrace_filters(opts),
        config: config,
        source_radius: config[:'exceptions.source_radius']
      )
    end

    # Unwrap the exception so that original exception is ignored or
    # reported.
    #
    # exception - The exception which was rescued.
    #
    # Returns the Exception to report.
    def unwrap_exception(exception)
      return exception unless config[:'exceptions.unwrap']
      exception_cause(exception) || exception
    end

    # Fetch cause from exception.
    #
    # exception - Exception to fetch cause from.
    #
    # Returns the Exception cause.
    def exception_cause(exception)
      e = exception
      if e.respond_to?(:cause) && e.cause && e.cause.is_a?(Exception)
        e.cause
      elsif e.respond_to?(:original_exception) && e.original_exception && e.original_exception.is_a?(Exception)
        e.original_exception
      elsif e.respond_to?(:continued_exception) && e.continued_exception && e.continued_exception.is_a?(Exception)
        e.continued_exception
      end
    end

    # Create a list of causes.
    #
    # cause - The first cause to unwrap.
    #
    # Returns Array causes (in Hash payload format).
    def unwrap_causes(cause)
      causes, c, i = [], cause, 0

      while c && i < MAX_EXCEPTION_CAUSES
        causes << {
          class: c.class.name,
          message: c.message,
          backtrace: parse_backtrace(c.backtrace || caller).to_a
        }
        i += 1
        c = exception_cause(c)
      end

      causes
    end

    def params_filters
      config.params_filters + rails_params_filters
    end

    def rails_params_filters
      rack_env && Array(rack_env['action_dispatch.parameter_filter']) or []
    end

    # This is how much Honeybadger cares about Rails developers. :)
    #
    # Some Rails projects include ActionDispatch::TestProcess globally for the
    # use of `fixture_file_upload` in tests. This is a bad practice because it
    # includes other methods -- such as #session -- which override existing
    # methods on *all objects*. This creates the following bug in Notice:
    #
    # When you call #session on any object which had previously defined it
    # (such as OpenStruct), that newly defined method calls #session on
    # +@request+ (defined in `ActionDispatch::TestProcess`), and if +@request+
    # doesn't exist in that object, it calls #session *again* on `nil`, which
    # also inherited it from Object, resulting in a SystemStackError.
    #
    # See https://stackoverflow.com/questions/18202261/include-actiondispatchtestprocess-prevents-guard-from-reloading-properly
    # for more info.
    #
    # This method restores the correct #session method on @request and warns
    # the user of the issue.
    #
    # Returns nothing.
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
