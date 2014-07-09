# Honeybadger

[![Build Status](https://secure.travis-ci.org/honeybadger-io/honeybadger-ruby.png?branch=master)](http://travis-ci.org/honeybadger-io/honeybadger-ruby)
[![Gem Version](https://badge.fury.io/rb/honeybadger.png)](http://badge.fury.io/rb/honeybadger)

This is the notifier gem for integrating apps with the :zap: [Honeybadger Exception Notifier for Ruby and Rails](http://honeybadger.io).

When an uncaught exception occurs, Honeybadger will POST the relevant data
to the Honeybadger server specified in your environment.

## Supported Ruby versions

#### IMPORTANT: As of version 1.16.0, Ruby 1.8.7 and 1.9.2 are unsupported. Please ensure you are running Ruby 1.9.3 or greater before upgrading.

Honeybadger supports Ruby 1.9.3 through 2.1.

## Supported Rails versions

Honeybadger supports Rails 2.3 through Rails 4.1 (latest releases).

## Documentation

[View the Documentation](http://docs.honeybadger.io/article/50-honeybadger-gem-documentation)

## Contributing

1. Fork it.
2. Create a topic branch `git checkout -b my_branch`
3. Commit your changes `git commit -am "Boom"`
3. Push to your branch `git push origin my_branch`
4. Send a [pull request](https://github.com/honeybadger-io/honeybadger-ruby/pulls)

### Running the tests

We're using the
[appraisal](https://github.com/thoughtbot/appraisal) gem to run our test
suite against multiple versions of Rails. To run the Cucumber features,
use `rake appraisal cucumber`. Type `rake -T` for a complete list of
available tasks.

The RSpec test suite can be run with `rake`, or
`rake appraisal:rails2.3` to include Rails-specific specs.

### License

The Honeybadger gem is MIT licensed. See the [MIT-LICENSE](https://raw.github.com/honeybadger-io/honeybadger-ruby/master/MIT-LICENSE) file in this repository for details. 
