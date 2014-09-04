require 'sinatra'
require 'honeybadger'

GC::Profiler.enable

# class Badgers < Sinatra::Application

get '/' do
  'Hello world!'
end

get '/test/failure' do
  fail 'Sinatra has left the building'
end

# end

# Badgers.run!
