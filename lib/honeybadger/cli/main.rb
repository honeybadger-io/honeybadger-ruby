require 'honeybadger/cli/deploy'
require 'honeybadger/cli/exec'
require 'honeybadger/cli/heroku'
require 'honeybadger/cli/install'
require 'honeybadger/cli/notify'
require 'honeybadger/cli/test'
require 'honeybadger/config'
require 'honeybadger/config/defaults'
require 'honeybadger/util/http'
require 'honeybadger/version'
require 'logger'

module Honeybadger
  module CLI
    BLANK = /\A\s*\z/

    NOTIFIER = {
      name: 'honeybadger-ruby (cli)'.freeze,
      url: 'https://github.com/honeybadger-io/honeybadger-ruby'.freeze,
      version: VERSION,
      language: nil
    }.freeze

    class Main < Thor
      def self.project_options
        option :api_key,     required: false, aliases: :'-k', type: :string, desc: 'Api key of your Honeybadger application'
        option :environment, required: false, aliases: [:'-e', :'-env'], type: :string, desc: 'Environment this command is being executed in (i.e. "production", "staging")'
      end

      desc 'install API_KEY', 'Install Honeybadger into a new project'
      def install(api_key)
        Install.new(options, api_key).run
      rescue => e
        log_error(e)
        exit(1)
      end

      desc 'test', 'Send a test notification from Honeybadger'
      option :dry_run, type: :boolean, aliases: :'-d', default: false, desc: 'Skip sending data to Honeybadger'
      option :file,    type: :string,  aliases: :'-f', default: nil, desc: 'Write the output to FILE'
      def test
        Test.new(options).run
      rescue => e
        log_error(e)
        exit(1)
      end

      desc 'deploy', 'Notify Honeybadger of deployment'
      project_options
      option :repository, required: true, type: :string, aliases: :'-r', desc: 'The address of your repository'
      option :revision,   required: true, type: :string, aliases: :'-s', desc: 'The revision/sha that is being deployed'
      option :user,       required: true, type: :string, aliases: :'-u', default: ENV['USER'] || ENV['USERNAME'], desc: 'The local user who is deploying'
      def deploy
        config = build_config(options)

        if config.get(:api_key).to_s =~ BLANK
          say("No value provided for required options '--api-key'")
          return
        end

        Deploy.new(options, [], config).run
      rescue => e
        log_error(e)
        exit(1)
      end

      desc 'notify', 'Notify Honeybadger of an error'
      project_options
      option :class,   required: true, type: :string, aliases: :'-c', default: 'CLI Notification', desc: 'The class name of the error. (Default: CLI Notification)'
      option :message, required: true, type: :string, aliases: :'-m', desc: 'The error message.'
      def notify
        config = build_config(options)
        config.set(:env, fetch_value(options, 'env')) if options.has_key?('env')

        if config.get(:api_key).to_s =~ BLANK
          say("No value provided for required options '--api-key'")
          return
        end

        Notify.new(options, [], config).run
      rescue => e
        log_error(e)
        exit(1)
      end

      desc 'exec', 'Execute a command. If the exit status is not 0, report the result to Honeybadger'
      project_options
      option :quiet, required: false, type: :boolean, aliases: :'-q', default: false, desc: 'Suppress all output unless Honeybdager notification fails.'
      def exec(*args)
        config = build_config(options)

        if config.get(:api_key).to_s =~ BLANK
          say("No value provided for required options '--api-key'")
          return
        end

        Exec.new(options, args, config).run
      rescue => e
        log_error(e)
        exit(1)
      end

      desc 'heroku SUBCOMMAND ...ARGS', 'Manage Honeybadger on Heroku'
      subcommand 'heroku', Heroku

      private

      def fetch_value(options, key)
        options[key] == key ? nil : options[key]
      end

      def build_config(options)
        config = Config.new(logger: Logger.new('/dev/null'))
        config.set(:api_key, fetch_value(options, 'api_key')) if options.has_key?('api_key')
        config.init!({
          framework: :cli,
          :'config.path' => ["#{ENV['HOME']}/honeybadger.yml"] | Config::DEFAULT_PATHS
        })
        config
      end

      def log_error(e)
        case e
        when *Util::HTTP::ERRORS
          say(<<-MSG, :red)
!! --- Failed to notify Honeybadger ------------------------------------------- !!

- What happened?

  We encountered an HTTP error while contacting our service. Issues like this are
  usually temporary.

- Error details

  #{e.class}: #{e.message}\n    at #{e.backtrace && e.backtrace.first}

- What can I do?

  - Retry the command.
  - Make sure you can connect to api.honeybadger.io (`ping api.honeybadger.io`).
  - If you continue to see this message, email us at support@honeybadger.io
    (don't forget to attach this output!)

!! --- End -------------------------------------------------------------------- !!
MSG
        else
          say(<<-MSG, :red)
!! --- Honeybadger command failed --------------------------------------------- !!

- What did you try to do?

  You tried to execute the following command:
  `honeybadger #{ARGV.join(' ')}`

- What actually happend?

  We encountered a Ruby exception and were forced to cancel your request.

- Error details

  #{e.class}: #{e.message}
    #{e.backtrace && e.backtrace.join("\n    ")}

- What can I do?

  - Retry the command.
  - If you continue to see this message, email us at support@honeybadger.io
    (don't forget to attach this output!)

!! --- End -------------------------------------------------------------------- !!
MSG
        end
      end
    end
  end
end
