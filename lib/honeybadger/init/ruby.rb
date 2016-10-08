Honeybadger::Agent.instance.init!({
  framework: :ruby,
  env: ENV['RUBY_ENV']
})

Honeybadger::Agent.load_plugins!
