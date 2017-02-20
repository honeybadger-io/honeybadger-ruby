require 'forwardable'
require 'honeybadger/cli/main'
require 'honeybadger/util/http'

module Honeybadger
  module CLI
    class Deploy
      extend Forwardable

      def initialize(options, args, config)
        @options = options
        @args = args
        @config = config
        @shell = ::Thor::Base.shell.new
      end

      def run
        payload = {
          environment: options['environment'],
          revision: options['revision'],
          repository: options['repository'],
          local_username: options['user']
        }

        result = config.backend.notify(:deploys, payload)
        if result.success?
          say("Deploy notification complete.", :green)
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
