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

at_exit do
  if $! && !$!.is_a?(SystemExit) && Honeybadger.config[:'exceptions.notify_at_exit']
    Honeybadger.notify($!, component: 'at_exit', sync: true)
  end
  Honeybadger.stop if Honeybadger.config[:'send_data_at_exit']
end
