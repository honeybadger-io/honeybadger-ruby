require 'stringio'

require 'honeybadger/cli/helpers'

module Honeybadger
  module CLI
    class Main < Thor
      include Helpers

      class HoneybadgerTestingException < RuntimeError; end

      NOT_BLANK = Regexp.new('\S').freeze

      desc 'deploy', 'Notify Honeybadger of deployment'
      option :environment, aliases: :'-e', type: :string, desc: 'Environment of the deploy (i.e. "production", "staging")'
      option :revision, aliases: :'-s', type: :string, desc: 'The revision/sha that is being deployed'
      option :repository, aliases: :'-r', type: :string, desc: 'The address of your repository'
      option :user, aliases: :'-u', type: :string, default: ENV['USER'] || ENV['USERNAME'], desc: 'The local user who is deploying'
      option :api_key, aliases: :'-k', type: :string, desc: 'Api key of your Honeybadger application'
      def deploy
        load_rails(verbose: true)

        payload = Hash[[:environment, :revision, :repository].map {|k| [k, options[k]] }]
        payload[:local_username] = options[:user]

        ENV['HONEYBADGER_LOGGING_LEVEL']     = '2'
        ENV['HONEYBADGER_LOGGING_TTY_LEVEL'] = '0'
        ENV['HONEYBADGER_LOGGING_PATH']      = 'STDOUT'
        ENV['HONEYBADGER_REPORT_DATA']       = 'true'

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
          exit(1)
        end
      rescue => e
        say("An error occurred during deploy notification: #{e}\n\t#{e.backtrace.join("\n\t")}", :red)
        exit(1)
      end

      desc 'config', 'List configuration options'
      option :default, aliases: :'-d', type: :boolean, default: true, desc: 'Output default options'
      def config
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

        load_rails(verbose: true)

        ENV['HONEYBADGER_LOGGING_LEVEL']     = '2'
        ENV['HONEYBADGER_LOGGING_TTY_LEVEL'] = '0'
        ENV['HONEYBADGER_LOGGING_PATH']      = 'STDOUT'
        ENV['HONEYBADGER_REPORT_DATA']       = 'true'

        config = Config.new(rails_framework_opts)
        config[:api_key] = api_key.to_s

        if (path = config.config_path).exist?
          say("You're already on Honeybadger, so you're all set.", :yellow)
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

        if (capfile = Pathname.new(config[:root]).join('Capfile')).exist?
          if capfile.read.match(/honeybadger/)
            say("Detected Honeybadger in Capfile; skipping Capistrano installation.", :yellow)
          else
            say("Appending Capistrano tasks to: #{capfile}", :yellow)
            File.open(capfile, 'a') do |f|
              f.puts("\nrequire 'capistrano/honeybadger'")
            end
          end
        end

        if options[:test].nil? || options[:test]
          Honeybadger.start(config) unless load_rails_env(verbose: true)
          say('Sending test notice', :yellow)
          unless Agent.instance && send_test(false)
            say('Honeybadger is installed, but failed to send a test notice. Try `honeybadger test`.', :red)
            exit(1)
          end
        end

        say("Installation complete. Happy 'badgering!", :green)
      end

      desc 'heroku SUBCOMMAND ...ARGS', 'Manage Honeybadger on Heroku'
      subcommand 'heroku', Heroku

      private

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
            say(indent + "Type: #{Config::OPTIONS[dotted_key].fetch(:type, String).name.split('::').last}")
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
    end
  end
end
