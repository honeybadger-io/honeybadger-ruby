require 'capistrano'

if defined?(Capistrano::Configuration.instance)
  require 'honeybadger/capistrano/legacy'
else
  load File.expand_path('../capistrano/tasks.rake', __FILE__)
end
