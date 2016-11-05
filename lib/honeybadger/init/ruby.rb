require 'honeybadger/ruby'

Honeybadger::Agent.instance.init!({
  :framework      => :ruby,
  :env            => ENV['RUBY_ENV'],
  :'logging.path' => 'STDOUT'
})

Honeybadger::Agent.load_plugins!
