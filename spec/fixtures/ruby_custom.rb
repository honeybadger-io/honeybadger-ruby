require 'honeybadger/ruby'

agent = Honeybadger::Agent.new(backend: 'debug', debug: true, api_key: 'asdf')

agent.notify(error_class: 'CustomHoneybadgerException', error_message: 'Test message')

raise "This should not be reported."
