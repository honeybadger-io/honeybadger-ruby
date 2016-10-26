require 'erb'
require 'forwardable'
require 'honeybadger/cli/main'
require 'honeybadger/util/http'
require 'honeybadger/util/stats'
require 'open3'
require 'ostruct'
require 'thor/shell'

module Honeybadger
  module CLI
    class Exec
      extend Forwardable

      FAILED_TEMPLATE = <<-MSG
Honeybadger detected failure or error output for the command:
`<%= args.join(' ') %>`

PROCESS ID: <%= pid %>

RESULT CODE: <%= code %>

ERROR OUTPUT:
<%= stderr %>

STANDARD OUTPUT:
<%= stdout %>
MSG

      NO_EXEC_TEMPLATE = <<-MSG
Honeybadger failed to execute the following command:
`<%= args.join(' ') %>`

The command was not executable. Try adjusting permissions on the file.
MSG

      NOT_FOUND_TEMPLATE = <<-MSG
Honeybadger failed to execute the following command:
`<%= args.join(' ') %>`

The command was not found. Make sure it exists in your PATH.
MSG

      def initialize(options, args, config)
        @options = options
        @args = args
        @config = config
        @shell = ::Thor::Base.shell.new
      end

      def run
        result = exec_cmd
        return if result.success

        payload = {
          api_key: config.get(:api_key),
          notifier: NOTIFIER,
          error: {
            class: 'honeybdager exec error',
            message: result.msg
          },
          request: {
            context: {
              executable: args.first,
              code: result.code,
              pid: result.pid
            }
          },
          server: {
            project_root: Dir.pwd,
            environment_name: config.get(:env),
            time: Time.now,
            stats: Util::Stats.all
          }
        }

        http = Util::HTTP.new(config)

        begin
          response = http.post('/v1/notices', payload)
        rescue
          say(result.msg)
          raise
        end

        if response.code != '201'
          say(result.msg)
          say("\nFailed to notify Honeybadger: #{response.code}", :red)
          exit(1)
        end

        unless quiet?
          say(result.msg)
          say("\nSuccessfully notified Honeybadger")
        end

        exit(0)
      end

      private

      attr_reader :options, :args, :config

      def_delegator :@shell, :say

      def quiet?
        !!options[:quiet]
      end

      def exec_cmd
        stdout, stderr, status = Open3.capture3(args.join(' '))

        pid = status.pid
        code = status.to_i
        msg = ERB.new(FAILED_TEMPLATE).result(binding) unless status.success?

        OpenStruct.new(
          msg: msg,
          pid: pid,
          code: code,
          stdout: stdout,
          stderr: stderr,
          success: status.success?
        )
      rescue Errno::EACCES, Errno::ENOEXEC
        OpenStruct.new(
          msg: ERB.new(NO_EXEC_TEMPLATE).result(binding),
          code: 126
        )
      rescue Errno::ENOENT
        OpenStruct.new(
          msg: ERB.new(NOT_FOUND_TEMPLATE).result(binding),
          code: 127
        )
      end
    end
  end
end
