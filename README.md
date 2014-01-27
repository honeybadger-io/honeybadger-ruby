# Honeybadger

[![Build Status](https://secure.travis-ci.org/honeybadger-io/honeybadger-ruby.png?branch=master)](http://travis-ci.org/honeybadger-io/honeybadger-ruby)
[![Gem Version](https://badge.fury.io/rb/honeybadger.png)](http://badge.fury.io/rb/honeybadger)

This is the notifier gem for integrating apps with the :zap: [Honeybadger Exception Notifier for Ruby and Rails](http://honeybadger.io).

When an uncaught exception occurs, Honeybadger will POST the relevant data
to the Honeybadger server specified in your environment.

## Documentation

[View the Documentation](http://docs.honeybadger.io/article/50-honeybadger-gem-documentation)

## Supported Ruby versions

Honeybadger supports Ruby 1.8.7 through 2.1.

## Supported Rails versions

Honeybadger supports Rails 2.3.18 through Rails 4.1.0.

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
