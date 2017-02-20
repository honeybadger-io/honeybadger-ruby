require 'digest'
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
          request: {},
          server: {
            project_root: Dir.pwd,
            environment_name: config.get(:env),
            time: Time.now,
            stats: Util::Stats.all
          }
        }

        payload[:error][:fingerprint] = Digest::SHA1.hexdigest(options['fingerprint']) if option?('fingerprint')
        payload[:error][:tags] = options['tags'].to_s.strip.split(',').map(&:strip) if option?('tags')

        payload[:request][:component] = options['component'] if option?('component')
        payload[:request][:action] = options['action'] if option?('action')
        payload[:request][:url] = options['url'] if option?('url')

        payload.delete(:request) if payload[:request].empty?

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

      def option?(key)
        options.has_key?(key) && options[key] != key
      end
    end
  end
end
