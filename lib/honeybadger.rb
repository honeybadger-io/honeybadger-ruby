require 'honeybadger/const'
require 'honeybadger/singleton'

if defined?(::Rails::Railtie)
  require 'honeybadger/init/rails'
elsif defined?(Sinatra::Base)
  require 'honeybadger/init/sinatra'
end

if defined?(Rake.application)
  require 'honeybadger/init/rake'
end
