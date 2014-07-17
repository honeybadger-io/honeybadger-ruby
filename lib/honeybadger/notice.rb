require 'honeybadger/payload'
require 'socket'

module Honeybadger
  class Notice
    # The exception that caused this notice, if any
    attr_reader :exception

    # The backtrace from the given exception or hash.
    attr_reader :backtrace

    # Custom fingerprint for error, used to group similar errors together (optional)
    attr_reader :fingerprint

    # The name of the class of error (such as RuntimeError)
    attr_reader :error_class

    # Excerpt from source file
    attr_reader :source_extract

    # The number of lines of context to include before and after source excerpt
    attr_reader :source_extract_radius

    # The name of the server environment (such as "production")
    attr_reader :environment_name

    # CGI variables such as HTTP_METHOD
    attr_reader :cgi_data

    # The message from the exception, or a general description of the error
    attr_reader :error_message

    # See Configuration#send_request_session
    attr_reader :send_request_session

    # See Configuration#backtrace_filters
    attr_reader :backtrace_filters

    # See Configuration#params_filters
    attr_reader :params_filters

    # A hash of parameters from the query string or post body.
    attr_reader :parameters
    alias_method :params, :parameters

    # The component (if any) which was used in this request (usually the controller)
    attr_reader :component
    alias_method :controller, :component

    # The action (if any) that was called in this request
    attr_reader :action

    # A hash of session data from the request
    attr_reader :session_data

    # Additional contextual information (custom data)
    attr_reader :context

    # The path to the project that caused the error (usually Rails.root)
    attr_reader :project_root

    # The URL at which the error occurred (if any)
    attr_reader :url

    # See Configuration#ignore
    attr_reader :ignore

    # See Configuration#ignore_by_filters
    attr_reader :ignore_by_filters

    # The name of the notifier library sending this notice, such as "Honeybadger Notifier"
    attr_reader :notifier_name

    # The version number of the notifier library sending this notice, such as "2.1.3"
    attr_reader :notifier_version

    # A URL for more information about the notifier library sending this notice
    attr_reader :notifier_url

    # The host name where this error occurred (if any)
    attr_reader :hostname

    # System stats
    attr_reader :stats

    # The api_key to use when sending notice (optional)
    attr_reader :api_key

    # Local variables are extracted from first frame of backtrace
    attr_reader :local_variables

    # Additional features to enable/disable
    attr_reader :features

    def initialize(args)
      self.args         = args
      self.features     = args[:features] || {}
      self.exception    = args[:exception]
      self.project_root = args[:project_root]

      self.notifier_name    = args[:notifier_name]
      self.notifier_version = args[:notifier_version]
      self.notifier_url     = args[:notifier_url]

      self.ignore              = args[:ignore]              || []
      self.ignore_by_filters   = args[:ignore_by_filters]   || []
      self.backtrace_filters   = args[:backtrace_filters]   || []
      self.params_filters      = args[:params_filters]      || []
      self.parameters          = args[:parameters] ||
                                   action_dispatch_params ||
                                   rack_env(:params) ||
                                   {}
      self.component           = args[:component] || args[:controller] || parameters['controller']
      self.action              = args[:action] || parameters['action']

      self.environment_name = args[:environment_name]
      self.cgi_data         = args[:cgi_data] || args[:rack_env]
      self.backtrace        = Backtrace.parse(exception_attribute(:backtrace, caller), :filters => self.backtrace_filters)
      self.fingerprint      = hashed_fingerprint
      self.error_class      = exception_attribute(:error_class) {|exception| exception.class.name }
      self.error_message    = trim_size(1024) do
        exception_attribute(:error_message, 'Notification') do |exception|
          "#{exception.class.name}: #{exception.message}"
        end
      end

      self.url              = args[:url] || rack_env(:url)
      self.hostname         = local_hostname
      self.stats            = Stats.all
      self.api_key          = args[:api_key]

      self.source_extract_radius = args[:source_extract_radius] || 2
      self.source_extract        = extract_source_from_backtrace

      self.local_variables = send_local_variables? ? local_variables_from_exception(exception) : {}

      self.send_request_session = args[:send_request_session].nil? ? true : args[:send_request_session]

      find_session_data
      also_use_rack_params_filters
      set_context
      clean_rack_request_data
    end

    # Deprecated. Remove in 2.0.
    def deliver
      return false unless Honeybadger.sender
      Honeybadger.sender.send_to_honeybadger(self)
    end

    # Public: Template used to create JSON payload
    #
    # Returns JSON representation of notice
    def as_json(options = {})
      Payload.new({
        :api_key => api_key,
        :notifier => {
          :name => notifier_name,
          :url => notifier_url,
          :version => notifier_version,
          :language => 'ruby'
        },
        :error => {
          :class => error_class,
          :message => error_message,
          :backtrace => backtrace,
          :source => source_extract,
          :fingerprint => fingerprint
        },
        :request => {
          :url => url,
          :component => component,
          :action => action,
          :params => parameters,
          :session => session_data,
          :cgi_data => cgi_data,
          :context => context,
          :local_variables => local_variables
        },
        :server => {
          :project_root => project_root,
          :environment_name => environment_name,
          :hostname => hostname,
          :stats => stats
        }
      }, :filters => params_filters)
    end

    # Public: Creates JSON
    #
    # Returns valid JSON representation of notice
    def to_json(*a)
      as_json.to_json(*a)
    end

    # Public: Determines if error class should be ignored
    #
    # ignored_class_name - The name of the ignored class. May be a
    # string or regexp (optional)
    #
    # Returns true/false with an argument, otherwise a Proc object
    def ignore_by_class?(ignored_class = nil)
      @ignore_by_class ||= Proc.new do |ignored_class|
        case error_class
        when (ignored_class.respond_to?(:name) ? ignored_class.name : ignored_class)
          true
        else
          exception && ignored_class.is_a?(Class) && exception.class < ignored_class
        end
      end

      ignored_class ? @ignore_by_class.call(ignored_class) : @ignore_by_class
    end

    # Public: Determines if this notice should be ignored
    def ignore?
      ignore.any?(&ignore_by_class?) ||
        ignore_by_filters.any? {|filter| filter.call(self) }
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

    private

    attr_writer :exception, :backtrace, :fingerprint, :error_class,
      :error_message, :backtrace_filters, :parameters, :params_filters,
      :environment_filters, :session_data, :project_root, :url, :ignore,
      :ignore_by_filters, :notifier_name, :notifier_url, :notifier_version,
      :component, :action, :cgi_data, :environment_name, :hostname, :stats,
      :context, :source_extract, :source_extract_radius, :send_request_session,
      :api_key, :features, :local_variables

    # Private: Arguments given in the initializer
    attr_accessor :args

    # Internal: Gets a property named "attribute" of an exception, either from
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
      args[attribute] || (exception && from_exception(attribute, &block)) || default
    end

    # Private: Gets a property named +attribute+ from an exception.
    #
    # If a block is given, it will be used when getting the property from an
    # exception. The block should accept and exception and return the value for
    # the property.
    #
    # If no block is given, a method with the same name as +attribute+ will be
    # invoked for the value.
    def from_exception(attribute)
      if block_given?
        yield(exception)
      else
        exception.send(attribute)
      end
    end

    def clean_rack_request_data
      if cgi_data
        self.cgi_data = cgi_data.reject {|k,_| k == 'QUERY_STRING' || !k.match(/\A[A-Z_]+\Z/) }
      end
    end

    def fingerprint_from_args
      if args[:fingerprint].respond_to?(:call)
        args[:fingerprint].call(self)
      else
        args[:fingerprint]
      end
    end

    def hashed_fingerprint
      fingerprint = fingerprint_from_args
      if fingerprint && fingerprint.respond_to?(:to_s)
        Digest::SHA1.hexdigest(fingerprint.to_s)
      end
    end

    def extract_source_from_backtrace
      if backtrace.lines.empty?
        nil
      else
        # ActionView::Template::Error has its own source_extract method.
        # If present, use that instead.
        if exception.respond_to?(:source_extract)
          Hash[exception.source_extract.split("\n").map do |line|
            parts = line.split(': ')
            [parts[0].strip, parts[1] || '']
          end]
        elsif backtrace.application_lines.any?
          backtrace.application_lines.first.source(source_extract_radius)
        else
          backtrace.lines.first.source(source_extract_radius)
        end
      end
    end

    def find_session_data
      if send_request_session
        self.session_data = args[:session_data] || args[:session] || rack_session || {}
        self.session_data = session_data[:data] if session_data[:data]
      end
    rescue => e
      # Rails raises ArgumentError when `config.secret_token` is missing, and
      # ActionDispatch::Session::SessionRestoreError when the session can't be
      # restored.
      self.session_data = { :error => "Failed to access session data -- #{e.message}" }
    end

    def set_context
      self.context = {}
      self.context.merge!(Thread.current[:honeybadger_context]) if Thread.current[:honeybadger_context]
      self.context.merge!(args[:context]) if args[:context]
      self.context = nil if context.empty?
    end

    def rack_env(method)
      rack_request.send(method) if rack_request
    rescue => e
      { :error => "Failed to call #{method} on Rack::Request -- #{e.message}" }
    end

    def rack_request
      @rack_request ||= if args[:rack_env]
        ::Rack::Request.new(args[:rack_env])
      end
    end

    def action_dispatch_params
      args[:rack_env]['action_dispatch.request.parameters'] if args[:rack_env]
    end

    def rack_session
      rack_env(:session).to_hash if args[:rack_env]
    end

    # Private: (Rails 3+) Adds params filters to filter list
    #
    # Returns nothing
    def also_use_rack_params_filters
      if cgi_data
        @params_filters ||= []
        @params_filters += cgi_data['action_dispatch.parameter_filter'] || []
      end
    end

    def local_hostname
      args[:hostname] || Socket.gethostname
    end

    # Internal: Limit size of string to bytes
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

    # Internal: Fetch local variables from first frame of backtrace.
    #
    # exception - The Exception containing the bindings stack.
    #
    # Returns a Hash of local variables
    def local_variables_from_exception(exception)
      return {} unless Exception === exception
      return {} unless exception.respond_to?(:__honeybadger_bindings_stack)
      return {} if exception.__honeybadger_bindings_stack.empty?

      if project_root
        binding = exception.__honeybadger_bindings_stack.find { |b| b.eval('__FILE__') =~ /^#{Regexp.escape(project_root.to_s)}/ }
      end

      binding ||= exception.__honeybadger_bindings_stack[0]

      vars = binding.eval('local_variables')
      Hash[vars.map {|arg| [arg, binding.eval(arg.to_s)]}]
    end

    # Internal: Should local variables be sent?
    #
    # Returns true to send local_variables
    def send_local_variables?
      args[:send_local_variables] && features['local_variables']
    end
  end
end
