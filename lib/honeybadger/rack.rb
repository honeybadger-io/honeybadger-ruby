require 'honeybadger/rack/error_notifier'
require 'honeybadger/rack/user_informer'
require 'honeybadger/rack/user_feedback'

module Honeybadger
  module Rack
    def self.new(*args, &block)
      warn '[DEPRECATION] Honeybadger::Rack is deprecated in 2.0. Use Honeybadger::Rack::ErrorNotifier.'
      ErrorNotifier.new(*args, &block)
    end
  end
end
