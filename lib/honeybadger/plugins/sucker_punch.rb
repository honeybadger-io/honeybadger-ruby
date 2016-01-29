require 'honeybadger/plugin'

module Honeybadger
  Plugin.register do
    requirement { defined?(::SuckerPunch) }

    execution do
      SuckerPunch.exception_handler = ->(ex, klass, args) { Honeybadger.notify(ex, { :component => klass, :parameters => args }) }
    end
  end
end

