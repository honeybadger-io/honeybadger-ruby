require 'sinatra/base'

class SinatraApp < Sinatra::Base
  set :show_exceptions, true
  set :honeybadger_api_key, 'gem testing'

  get '/runtime_error' do
    raise 'exception raised from test Sinatra app in honeybadger gem test suite'
  end

  get '/' do
    'This is a test Sinatra app used by the honeybadger gem test suite.'
  end
end
