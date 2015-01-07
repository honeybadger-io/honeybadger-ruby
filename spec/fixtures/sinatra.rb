require 'sinatra/base'
require 'honeybadger'
require 'sham_rack'

ShamRack.at("api.honeybadger.io", 443).stub.tap do |app|
  app.register_resource("/v1/notices/", %({"id":"123456789"}), "application/json")
  app.register_resource("/v1/ping/", %({"features":{"notices":true,"feedback":true}, "limit":null}), "application/json")
end

class BadgerApp < Sinatra::Base
  set :show_exceptions, true
  set :honeybadger_api_key, 'cobras'
  get '/test/failure' do
    fail 'Sinatra has left the building'
  end
end

app = BadgerApp
