if defined?(::Rails::Railtie)
  require 'honeybadger/init/rails'
elsif defined?(Sinatra::Base)
  require 'honeybadger/init/sinatra'
elsif defined?(::Hanami)
  require 'honeybadger/init/hanami'
else
  require 'honeybadger/init/ruby'
end

if defined?(Rake.application)
  require 'honeybadger/init/rake'
end
