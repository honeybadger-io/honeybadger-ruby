require 'honeybadger/cli/heroku'
require 'honeybadger/config'
require 'honeybadger/util/http'
require 'honeybadger/util/stats'
require 'honeybadger/version'
require 'logger'


module Honeybadger
  module CLI
    class Main < Thor
      DEFAULT_ENV = ENV['HONEYBADGER_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV']
      DEFAULT_USERNAME = ENV['USER'] || ENV['USERNAME']
      NOT_BLANK = /\S/

      NOTIFIER = {
        name: 'honeybadger-ruby (cli)'.freeze,
        url: 'https://github.com/honeybadger-io/honeybadger-ruby'.freeze,
        version: VERSION,
        language: nil
      }.freeze

      desc 'deploy', 'Notify Honeybadger of deployment'
      option :environment, required: true, aliases: :'-e', type: :string, default: DEFAULT_ENV, desc: 'Environment of the deploy (i.e. "production", "staging")'
      option :revision, required: true, aliases: :'-s', type: :string, desc: 'The revision/sha that is being deployed'
      option :repository, required: true, aliases: :'-r', type: :string, desc: 'The address of your repository'
      option :user, required: true, aliases: :'-u', type: :string, default: DEFAULT_USERNAME, desc: 'The local user who is deploying'
      option :api_key, required: false, aliases: :'-k', type: :string, desc: 'Api key of your Honeybadger application'
      def deploy
        config = build_config(options)

        if config.get(:api_key).to_s !~ NOT_BLANK
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
      end

      desc 'notify', 'Notify Honeybadger of an error'
      option :class,   type: :string, required: true, aliases: :'-c', default: 'CLI Notification', desc: 'The class name of the error. (Default: CLI Notification)'
      option :message, type: :string, required: true, aliases: :'-m', desc: 'The error message.'
      option :api_key, type: :string, required: false, aliases: :'-k', desc: 'Api key of your Honeybadger application'
      option :env,     type: :string, required: false, aliases: :'-e', desc: 'Environment this command is being executed in (i.e. "production", "staging")'
      def notify
        config = build_config(options)
        config.set(:env, fetch_value(options, 'env')) if options.has_key?('env')

        if config.get(:api_key).to_s !~ NOT_BLANK
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
    end
  end
end
