require 'honeybadger/ruby'

agent = Honeybadger::Agent.new({
  api_key: 'asdf',
  backend: 'debug',
  debug: true,
  logger: Logger.new(STDOUT)
})

agent.notify(error_class: 'CustomHoneybadgerException', error_message: 'Test message')

agent.flush

raise 'This should not be reported.'
