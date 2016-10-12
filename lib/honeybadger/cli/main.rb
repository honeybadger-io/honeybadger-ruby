module Honeybadger
  module CLI
    class Main < Thor
      desc 'heroku SUBCOMMAND ...ARGS', 'Manage Honeybadger on Heroku'
      subcommand 'heroku', Heroku
    end
  end
end
