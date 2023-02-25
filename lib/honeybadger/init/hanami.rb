require 'honeybadger/ruby'

Honeybadger.init!({
  :framework => :hanami,
  :env => ENV['HANAMI_ENV'] || ENV['RACK_ENV'],
  :'logging.path' => 'STDOUT'
})

Honeybadger.load_plugins!

if Hanami::VERSION >= '2.0'
  Hanami.app.instance_eval do
    config.middleware.use Honeybadger::Rack::UserFeedback
    config.middleware.use Honeybadger::Rack::UserInformer
    config.middleware.use Honeybadger::Rack::ErrorNotifier
  end
end

Honeybadger.install_at_exit_callback
