require 'thor'
require 'honeybadger'

require 'sham_rack'

ShamRack.at("api.honeybadger.io", 443).stub.tap do |app|
  app.register_resource("/v1/notices/", %({"id":"123456789"}), "application/json")
  app.register_resource("/v1/ping/", %({"features":{"notices":true,"feedback":true}, "limit":null}), "application/json")
end

Honeybadger.configure do |config|
  config.api_key = 'asdf'
  config.debug = true
  config.logger = Logger.new(STDOUT)
end

class Test < Thor
  desc "honeybadger", "this goes boom"
  def honeybadger
    fail 'boom'
  end
end
