require 'forwardable'
require 'honeybadger/cli/main'
require 'honeybadger/cli/helpers'
require 'honeybadger/util/http'

module Honeybadger
  module CLI
    class Checkins
      extend Forwardable
      include Helpers::BackendCmd

      def initialize(options, args, config)
        @options = options
        @args = args
        @config = config
        @shell = ::Thor::Base.shell.new
      end
      
      def run
        
        say("Checkin config synced", :green)
      end

      private

      attr_reader :options, :args, :config

      def_delegator :@shell, :say
    end
  end
end