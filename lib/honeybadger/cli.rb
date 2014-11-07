$:.unshift(File.expand_path('../../../vendor/thor/lib', __FILE__))

require 'thor'

require 'honeybadger'
require 'honeybadger/cli/heroku'
require 'honeybadger/cli/honeybadger'

module Honeybadger
  module CLI
    def self.start(*args)
      Honeybadger.start(*args)
    end
  end
end
