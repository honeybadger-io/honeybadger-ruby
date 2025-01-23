require "sinatra/base"

class SinatraApp < Sinatra::Base
  set :host_authorization, {permitted_hosts: []}
  set :show_exceptions, false
  set :honeybadger_api_key, "gem testing"

  get "/runtime_error" do
    raise "exception raised from test Sinatra app in honeybadger gem test suite"
  end

  get "/" do
    "This is a test Sinatra app used by the honeybadger gem test suite."
  end

  error 500 do
    "An error happened. <!-- HONEYBADGER ERROR -->"
  end
end
