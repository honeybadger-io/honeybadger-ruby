require 'honeybadger/ruby'

Honeybadger.init!({
  :framework      => :ruby,
  :env            => ENV['RUBY_ENV'],
  :'logging.path' => 'STDOUT'
})

Honeybadger.load_plugins!
