require 'forwardable'

module Honeybadger
  module Backend
    class BackendError < StandardError; end

    def self.mapping
      @@mapping ||= {
        server: Server,
        test: Test,
        null: Null,
        debug: Debug
      }.freeze
    end

    def self.for(backend)
      mapping[backend] or raise(BackendError, "Unable to locate backend: #{backend}")
    end

    autoload :Base, 'honeybadger/backend/base'
    autoload :Server, 'honeybadger/backend/server'
    autoload :Test, 'honeybadger/backend/test'
    autoload :Null, 'honeybadger/backend/null'
    autoload :Debug, 'honeybadger/backend/debug'
  end
end
