require 'honeybadger/cli/heroku'
require 'honeybadger/cli/exec'
require 'honeybadger/config'
require 'honeybadger/util/http'
require 'honeybadger/util/stats'
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
      DEFAULT_ENV = ENV['HONEYBADGER_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV']
      DEFAULT_USERNAME = ENV['USER'] || ENV['USERNAME']

      desc 'deploy', 'Notify Honeybadger of deployment'
      option :environment, required: true, aliases: :'-e', type: :string, default: DEFAULT_ENV, desc: 'Environment of the deploy (i.e. "production", "staging")'
      option :revision, required: true, aliases: :'-s', type: :string, desc: 'The revision/sha that is being deployed'
      option :repository, required: true, aliases: :'-r', type: :string, desc: 'The address of your repository'
      option :user, required: true, aliases: :'-u', type: :string, default: DEFAULT_USERNAME, desc: 'The local user who is deploying'
      option :api_key, required: false, aliases: :'-k', type: :string, desc: 'Api key of your Honeybadger application'
      def deploy
        config = build_config(options)

        if config.get(:api_key).to_s =~ BLANK
          say("No value provided for required options '--api-key'")
          return
        end

        payload = {
          environment: options[:environment],
          revision: options[:revision],
          repository: options[:repository],
          local_username: options[:user]
        }

        http = Util::HTTP.new(config)
        result = http.post('/v1/deploys', payload)
        if result.code == '201'
          say("Deploy notification complete.", :green)
        else
          say("Invalid response from server: #{result.code}", :red)
          exit(1)
        end
      rescue => e
        log_error(e)
        exit(1)
      end

      desc 'notify', 'Notify Honeybadger of an error'
      option :class,   type: :string, required: true, aliases: :'-c', default: 'CLI Notification', desc: 'The class name of the error. (Default: CLI Notification)'
      option :message, type: :string, required: true, aliases: :'-m', desc: 'The error message.'
      option :api_key, type: :string, required: false, aliases: :'-k', desc: 'Api key of your Honeybadger application'
      option :env,     type: :string, required: false, aliases: :'-e', desc: 'Environment this command is being executed in (i.e. "production", "staging")'
      def notify
        config = build_config(options)
        config.set(:env, fetch_value(options, 'env')) if options.has_key?('env')

        if config.get(:api_key).to_s =~ BLANK
          say("No value provided for required options '--api-key'")
          return
        end

        payload = {
          api_key: config.get(:api_key),
          notifier: NOTIFIER,
          error: {
            class: options['class'],
            message: options['message']
          },
          server: {
            project_root: Dir.pwd,
            environment_name: config.get(:env),
            time: Time.now,
            stats: Util::Stats.all
          }
        }

        http = Util::HTTP.new(config)
        result = http.post('/v1/notices', payload)
        if result.code == '201'
          say("Error notification complete.", :green)
        else
          say("Invalid response from server: #{result.code}", :red)
          exit(1)
        end
      rescue => e
        log_error(e)
        exit(1)
      end

      desc 'exec', 'Execute a command. If the exit status is not 0, report the result to Honeybadger'
      option :api_key, required: false, aliases: :'-k', type: :string, desc: 'Api key of your Honeybadger application'
      option :quiet,   required: false, aliases: :'-q', default: false, type: :boolean, desc: 'Suppress all output unless Honeybdager notification fails.'
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
          framework: :cli
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
