require 'sinatra/base'
require 'honeybadger'

class BadgerApp < Sinatra::Base
  set :show_exceptions, true
  set :honeybadger_api_key, 'cobras'
  get '/test/failure' do
    fail 'Sinatra has left the building'
  end
end

app = BadgerApp
