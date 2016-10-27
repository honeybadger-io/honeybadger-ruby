require 'forwardable'
require 'honeybadger/cli/main'
require 'honeybadger/util/http'
require 'honeybadger/util/stats'

module Honeybadger
  module CLI
    class Notify
      extend Forwardable

      def initialize(options, args, config)
        @options = options
        @args = args
        @config = config
        @shell = ::Thor::Base.shell.new
      end

      def run
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

      private

      attr_reader :options, :args, :config

      def_delegator :@shell, :say
    end
  end
end
