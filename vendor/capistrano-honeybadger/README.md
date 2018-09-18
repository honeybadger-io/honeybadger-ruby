# Capistrano::Honeybadger

Provides Honeybadger tasks for Capistrano 3:

* `cap honeybadger:deploy`

Some options:

```ruby
set :honeybadger, 'honeybadger'                # The honeybadger executable name
set :honeybadger_env, 'production'             # The environment which is being deployed
set :honeybadger_user, 'josh'                  # The user doing the deploying
set :honeybadger_api_key, 'asdf'               # The Honeybadger API key
set :honeybadger_server, primary(:app)         # The server performing the notification
set :repo_url, 'git@github.com:me/my_repo.git' # The repository url
set :current_revision, '88f1662'               # The revision being deployed
```

## Installation

This package is included in the Honeybadger gem:

```sh
gem 'capistrano',  '~> 3.1'
gem 'honeybadger', '~> 2.0'
```

## Usage

```ruby
# Capfile
require 'capistrano/honeybadger'

# production.rb / staging.rb / etc.
after 'deploy:finishing', 'honeybadger:deploy' 
```

Please note that any `require` should be placed in `Capfile`, not `config/deploy.rb`.

## Contributing

See [to contribute your code](../../README.md#to-contribute-your-code)
