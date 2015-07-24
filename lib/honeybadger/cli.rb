$:.unshift(File.expand_path('../../../vendor/cli', __FILE__))

require 'thor'

require 'honeybadger'
require 'honeybadger/cli/heroku'
require 'honeybadger/cli/main'

module Honeybadger
  module CLI
    def self.start(*args)
      Main.start(*args)
    end
  end
end
