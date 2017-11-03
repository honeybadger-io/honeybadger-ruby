if defined?(::Rails::Railtie)
  require 'honeybadger/init/rails'
elsif defined?(Sinatra::Base)
  require 'honeybadger/init/sinatra'
else
  require 'honeybadger/init/ruby'
end

if defined?(Rake.application)
  require 'honeybadger/init/rake'
end

# Sinatra is a special case. Sinatra starts the web application in an at_exit
# handler. And, since we require sinatra before requiring HB, the only way to
# setup our at_exit callback is in the sinatra build callback honeybadger/init/sinatra.rb
if !defined?(Sinatra::Base)
  Honeybadger.install_at_exit_callback
end
