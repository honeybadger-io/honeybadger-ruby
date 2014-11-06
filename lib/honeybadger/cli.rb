$:.unshift(File.expand_path('../../../vendor/thor/lib', __FILE__))
$:.unshift(File.expand_path('../../../vendor/inifile/lib', __FILE__))

require 'thor'
require 'honeybadger'
require 'stringio'
require 'logger'

module Honeybadger
  class CLI < Thor
    class HoneybadgerTestingException < RuntimeError; end

    NOT_BLANK = Regexp.new('\S').freeze

    class_option :platform, aliases: :'-p', type: :string, default: nil, desc: 'Specify optional PLATFORM (e.g. "heroku")'
    class_option :app, aliases: :'-a', type: :string, default: nil, desc: 'Specify optional APP with PLATFORM'

    desc 'deploy', 'Notify Honeybadger of deployment'
    option :environment, aliases: :'-e', type: :string, desc: 'Environment of the deploy (i.e. "production", "staging")'
    option :revision, aliases: :'-s', type: :string, desc: 'The revision/sha that is being deployed'
    option :repository, aliases: :'-r', type: :string, desc: 'The address of your repository'
    option :user, aliases: :'-u', type: :string, default: ENV['USER'] || ENV['USERNAME'], desc: 'The local user who is deploying'
    option :api_key, aliases: :'-k', type: :string, desc: 'Api key of your Honeybadger application'
    def deploy
      load_platform(options[:platform], options[:app])

      load_rails(verbose: true)

      payload = Hash[[:environment, :revision, :repository, :user].map {|k| [k, options[k]] }]

      say('Loading configuration')
      config = Config.new(rails_framework_opts)
      config.update(api_key: options[:api_key]) if options[:api_key] =~ NOT_BLANK

      unless (payload[:environment] ||= config[:env]) =~ NOT_BLANK
        say('Unable to determine environment. (see: `honeybadger help deploy`)', :red)
        exit(1)
      end

      unless config.valid?
        say("Invalid configuration: #{config.inspect}", :red)
        exit(1)
      end

      response = config.backend.notify(:deploys, payload)
      if response.success?
        say("Deploy notification for #{payload[:environment]} complete.", :green)
      else
        say("Deploy notification failed: #{response.code}", :red)
      end
    rescue => e
      say("An error occurred during deploy notification: #{e}\n\t#{e.backtrace.join("\n\t")}", :red)
      exit(1)
    end

    desc 'config', 'List configuration options'
    option :default, aliases: :'-d', type: :boolean, default: true, desc: 'Output default options'
    def config
      load_platform(options[:platform], options[:app])
      load_rails
      config = Config.new(rails_framework_opts)
      output_config(config.to_hash(options[:default]))
    end

    desc 'test', 'Output test/debug information'
    option :dry_run, aliases: :'-d', type: :boolean, default: false, desc: 'Skip sending data to Honeybadger'
    option :file, aliases: :'-f', type: :string, default: nil, desc: 'Write the output to FILE'
    def test
      if options[:file]
        out = StringIO.new
        $stdout = out

        flush = Proc.new do
          $stdout = STDOUT
          File.open(options[:file], 'w+') do |f|
            out.rewind
            out.each_line {|l| f.write(l) }
          end

          say("Output written to #{options[:file]}", :green)
        end

        Agent.at_exit(&flush)

        at_exit do
          # If the agent couldn't be started, the callback should happen here
          # instead.
          flush.() unless Agent.running?
        end
      end

      if load_platform(options[:platform], options[:app])
        say("\n") # Print a blank line if we just logged the platform.
      end

      say("Detecting framework\n\n", :bold)
      load_rails(verbose: true)

      ENV['HONEYBADGER_LOGGING_LEVEL']     = '0'
      ENV['HONEYBADGER_LOGGING_TTY_LEVEL'] = '0'
      ENV['HONEYBADGER_LOGGING_PATH']      = 'STDOUT'
      ENV['HONEYBADGER_DEBUG']             = 'true'
      ENV['HONEYBADGER_REPORT_DATA']       = options[:dry_run] ? 'false' : 'true'

      config = Config.new(rails_framework_opts)
      say("\nConfiguration\n\n", :bold)
      output_config(config.to_hash)

      say("\nStarting Honeybadger\n\n", :bold)
      Honeybadger.start(config) unless load_rails_env(verbose: true)

      say("\nSending test notice\n\n", :bold)
      send_test

      say("\nRunning at exit hooks\n\n", :bold)
    end

    desc 'install API_KEY', 'Install Honeybadger into the current directory using API_KEY'
    option :test, aliases: :'-t', type: :boolean, default: nil, desc: 'Send a test error'
    def install(api_key)
      say("Installing Honeybadger #{VERSION}")

      platform, app = load_platform(options[:platform], options[:app])

      load_rails(verbose: true)

      ENV['HONEYBADGER_LOGGING_LEVEL']     = '2'
      ENV['HONEYBADGER_LOGGING_TTY_LEVEL'] = '0'
      ENV['HONEYBADGER_LOGGING_PATH']      = 'STDOUT'
      ENV['HONEYBADGER_REPORT_DATA']       = 'true'

      config = Config.new(rails_framework_opts)
      config[:api_key] = api_key

      if platform == 'heroku'
        say("Adding config HONEYBADGER_API_KEY=#{api_key} to heroku.", :magenta)
        ENV['HONEYBADGER_API_KEY'] = api_key
        unless write_heroku_env({'HONEYBADGER_API_KEY' => api_key}, app)
          say('Unable to update heroku config. Do you need to specify an app name?', :red)
          exit(1)
        end
      elsif (path = config.config_path).exist?
        say("You're already on Honeybadger, so you're all set.", :yellow)
        skip_test = true if options[:test].nil? # Only if it wasn't specified.
      else
        say("Writing configuration to: #{path}", :yellow)

        begin
          config.write
        rescue Config::ConfigError => e
          error("Error: Unable to write configuration file:\n\t#{e}")
          return
        rescue StandardError => e
          error("Error: Unable to write configuration file:\n\t#{e.class} -- #{e.message}\n\t#{e.backtrace.join("\n\t")}")
          return
        end
      end

      if !skip_test && (options[:test].nil? || options[:test])
        Honeybadger.start(config) unless load_rails_env(verbose: true)
        say('Sending test notice', :yellow)
        unless Agent.instance && send_test(false)
          say('Honeybadger is installed, but failed to send a test notice. Try `honeybadger debug --test`.', :red)
          return
        end
      end

      say("Installation complete. Happy 'badgering!", :green)
    end

    private

    def rails?(opts = {})
      @rails ||= load_rails(opts)
    end

    def load_rails(opts = {})
      begin
        require 'honeybadger/init/rails'
        if ::Rails::VERSION::MAJOR >= 3
          say("Detected Rails #{::Rails::VERSION::STRING}") if opts[:verbose]
        else
          say("Error: Rails #{::Rails::VERSION::STRING} is unsupported.", :red)
          exit(1)
        end
      rescue LoadError
        say("Rails was not detected, loading standalone.") if opts[:verbose]
        return @rails = false
      rescue StandardError => e
        say("Error while detecting Rails: #{e.class} -- #{e.message}", :red)
        exit(1)
      end

      begin
        require File.expand_path('config/application')
      rescue LoadError
        say('Error: could not load Rails application. Please ensure you run this command from your project root.', :red)
        exit(1)
      end

      @rails = true
    end

    def load_rails_env(opts = {})
      return false unless rails?(opts)

      puts('Loading Rails environment') if opts[:verbose]
      begin
        require File.expand_path('config/environment')
      rescue LoadError
        say('Error: could not load Rails environment. Please ensure you run this command from your project root.', :red)
        exit(1)
      end

      true
    end

    def rails_framework_opts
      return {} unless defined?(::Rails)

      {
        :root           => ::Rails.root,
        :env            => ::Rails.env,
        :'config.path'  => ::Rails.root.join('config', 'honeybadger.yml'),
        :framework_name => "Rails #{::Rails::VERSION::STRING}",
        :api_key        => rails_secrets_api_key
      }
    end

    def rails_secrets_api_key
      if defined?(::Rails.application.secrets)
        ::Rails.application.secrets.honeybadger_api_key
      end
    end

    def output_config(nested_hash, hierarchy = [])
      nested_hash.each_pair do |key, value|
        if value.kind_of?(Hash)
          say(tab_indent(hierarchy.size) << "#{key}:")
          output_config(value, hierarchy + [key])
        else
          dotted_key = (hierarchy + [key]).join('.').to_sym
          say(tab_indent(hierarchy.size) << "#{key}:")
          indent = tab_indent(hierarchy.size+1)
          say(indent + "Description: #{Config::OPTIONS[dotted_key][:description]}")
          say(indent + "Default: #{Config::OPTIONS[dotted_key][:default].inspect}")
          say(indent + "Current: #{value.inspect}")
        end
      end
    end

    def tab_indent(number)
      ''.tap do |s|
        number.times { s << "\s\s" }
      end
    end

    # Public: Load platform (currently this means Heroku).
    #
    # platform - The platform to use. (optional: If platform and app are both
    #            nil we'll attempt to detect Heroku from GIT.)
    # app      - The app to use if a platform is detected. (optional)
    #
    # Returns Array [platform, app] if loaded, otherwise nil.
    def load_platform(platform = nil, app = nil)
      # We never want to detect/prompt the user unless we're attached to a terminal.
      if STDIN.tty? && !ENV['HONEYBADGER_DISABLE_DETECT_PLATFORM'] && (!platform || platform == 'heroku') && !app
        platform = 'heroku' if app = detect_heroku_app(platform != 'heroku')
      end

      if platform == 'heroku'
        say("Using platform: #{platform}" << (app ? " (app: #{app})" : "") << "\n")
        unless set_env_from_heroku(app)
          say("Unable to load ENV from Heroku. Do you need to specify an app name?", :red)
          exit(1)
        end

        return [platform, app]
      end

      nil
    end

    # Public: Detects the Heroku app name from GIT.
    #
    # prompt_on_default - If a single remote is discoverd, should we prompt the
    #                     user before returning it?
    #
    # Returns the String app name if detected, otherwise nil.
    def detect_heroku_app(prompt_on_default = true)
      apps, git_config = {}, File.join(Dir.pwd, '.git', 'config')
      if File.exist?(git_config)
        require 'inifile'
        ini = IniFile.load(git_config)
        ini.each_section do |section|
          if match = section.match(/remote \"(?<remote>.+)\"/)
            url = ini[section]['url']
            if url_match = url.match(/heroku\.com:(?<app>.+)\.git$/)
              apps[match[:remote]] = url_match[:app]
            end
          end
        end

        if apps.size == 1
          if !prompt_on_default
            apps.values.first
          else
            say "We detected a Heroku app named #{apps.values.first}. Do you want to load the config? (y/yes or n/no)"
            if STDIN.gets.chomp =~ /(y|yes)/i
              apps.values.first
            end
          end
        elsif apps.size > 1
          say "We detected the following Heroku apps:"
          apps.each_with_index {|a,i| say "\s\s#{i+1}. #{a[1]}" }
          say "\s\s#{apps.size+1}. Skip Heroku config."
          say "Please select an option (1-#{apps.size+1}):"
          apps.values[STDIN.gets.chomp.to_i-1]
        end
      end
    end

    def read_heroku_env(app = nil)
      cmd = ['heroku config']
      cmd << "--app #{app}" if app
      output = Bundler.with_clean_env { `#{cmd.join("\s")}` }
      return false unless $?.to_i == 0
      Hash[output.scan(/(HONEYBADGER_[^:]+):\s*(\S.*)\s*$/)]
    end

    def set_env_from_heroku(app = nil)
      return false unless env = read_heroku_env(app)
      env.each_pair do |k,v|
        ENV[k] ||= v
      end
    end

    def write_heroku_env(env, app = nil)
      cmd = ["heroku config:set"]
      Hash(env).each_pair {|k,v| cmd << "#{k}=#{v}" }
      cmd << "--app #{app}" if app
      Bundler.with_clean_env { `#{cmd.join("\s")}` }
      $?.to_i == 0
    end

    def test_exception_class
      exception_name = ENV['EXCEPTION'] || 'HoneybadgerTestingException'
      Object.const_get(exception_name)
    rescue
      Object.const_set(exception_name, Class.new(Exception))
    end

    def send_test(verbose = true)
      if defined?(::Rails)
        rails_test(verbose)
      else
        standalone_test
      end
    end

    def standalone_test
      Honeybadger.notify(test_exception_class.new('Testing honeybadger via "honeybadger test". If you can see this, it works.'))
    end

    def rails_test(verbose = true)
      if verbose
        ::Rails.logger = if defined?(::ActiveSupport::TaggedLogging)
                           ::ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
                         else
                           Logger.new(STDOUT)
                         end
        ::Rails.logger.level = Logger::INFO
      end

      # Suppress error logging in Rails' exception handling middleware. Rails 3.0
      # uses ActionDispatch::ShowExceptions to rescue/show exceptions, but does
      # not log anything but application trace. Rails 3.2 now falls back to
      # logging the framework trace (moved to ActionDispatch::DebugExceptions),
      # which caused cluttered output while running the test task.
      defined?(::ActionDispatch::DebugExceptions) and
        ::ActionDispatch::DebugExceptions.class_eval { def logger(*args) ; @logger ||= Logger.new('/dev/null') ; end }
      defined?(::ActionDispatch::ShowExceptions) and
      ::ActionDispatch::ShowExceptions.class_eval { def logger(*args) ; @logger ||= Logger.new('/dev/null') ; end }

      # Detect and disable the better_errors gem
      if defined?(::BetterErrors::Middleware)
        say('Better Errors detected: temporarily disabling middleware.', :yellow)
        ::BetterErrors::Middleware.class_eval { def call(env) @app.call(env); end }
      end

      begin
        require './app/controllers/application_controller'
      rescue LoadError
        nil
      end

      unless defined?(::ApplicationController)
        say('Error: No ApplicationController found.', :red)
        return false
      end

      say('Setting up the Controller.')
      ::ApplicationController.class_eval do
        # This is to bypass any filters that may prevent access to the action.
        prepend_before_filter :test_honeybadger
        def test_honeybadger
          puts "Raising '#{exception_class.name}' to simulate application failure."
          raise exception_class.new, 'Testing honeybadger via "rake honeybadger:test". If you can see this, it works.'
        end

        # Ensure we actually have an action to go to.
        def verify; end

        def exception_class
          exception_name = ENV['EXCEPTION'] || 'HoneybadgerTestingException'
          Object.const_get(exception_name)
        rescue
          Object.const_set(exception_name, Class.new(Exception))
        end
      end

      ::Rails.application.routes.draw do
        match 'verify' => 'application#verify', :as => 'verify', :via => :get
      end

      say('Processing request.')

      ssl = defined?(::Rails.configuration.force_ssl) && ::Rails.configuration.force_ssl
      env = ::Rack::MockRequest.env_for("http#{ ssl ? 's' : nil }://www.example.com/verify", 'REMOTE_ADDR' => '127.0.0.1')

      ::Rails.application.call(env)
    end
  end
end
