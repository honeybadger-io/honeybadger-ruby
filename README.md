# Honeybadger for Ruby

[![Code Climate](https://codeclimate.com/github/honeybadger-io/honeybadger-ruby/badges/gpa.svg)](https://codeclimate.com/github/honeybadger-io/honeybadger-ruby)
[![Test Coverage](https://codeclimate.com/github/honeybadger-io/honeybadger-ruby/badges/coverage.svg)](https://codeclimate.com/github/honeybadger-io/honeybadger-ruby)
[![Build Status](https://secure.travis-ci.org/honeybadger-io/honeybadger-ruby.png?branch=master)](http://travis-ci.org/honeybadger-io/honeybadger-ruby)
[![Gem Version](https://badge.fury.io/rb/honeybadger.png)](http://badge.fury.io/rb/honeybadger)

This is the notifier gem for integrating apps with the :zap: [Honeybadger Exception Notifier for Ruby and Rails](http://honeybadger.io).

When an uncaught exception occurs, Honeybadger will POST the relevant data to the Honeybadger server specified in your environment.

## Supported Ruby versions

Honeybadger officially supports the following Ruby versions and implementations:

| Ruby          | Version           |
| ------------- | ------------------|
| MRI           | >= 1.9.3          |
| JRuby         | >= 1.7 (1.9 mode) |
| Rubinius      | >= 2.0            |

## Supported frameworks

The following frameworks are supported:

| Framework     | Version       | Native?    |
| ------------- | ------------- |------------|
| Rails         | >= 3.0        | yes        |
| Sinatra       | >= 1.2.1      | yes        |
| Rack          | >= 1.0        | middleware |

Rails and Sinatra are supported natively (install/configure the gem and you're done). For vanilla Rack apps, we provide a collection of middleware that must be installed manually.

Integrating with other libraries/frameworks is simple! [See the documentation](http://rubydoc.info/gems/honeybadger/) to learn about our public API, and see [Contributing](#contributing) to suggest a patch.

## Documentation

* [Basic usage](http://rubydoc.info/gems/honeybadger/)
* [Full documentation](http://docs.honeybadger.io/article/50-honeybadger-gem-documentation)

## Changelog

See https://github.com/honeybadger-io/honeybadger-ruby/releases

## Contributing

If you're adding a new feature, please [submit an issue](https://github.com/honeybadger-io/honeybadger-ruby/issues/new) as a preliminary step; that way you can be (moderately) sure that your pull request will be accepted.

### To contribute your code:

1. Fork it.
2. Create a topic branch `git checkout -b my_branch`
3. Commit your changes `git commit -am "Boom"`
3. Push to your branch `git push origin my_branch`
4. Send a [pull request](https://github.com/honeybadger-io/honeybadger-ruby/pulls)

### Running the tests

We're using the [Appraisal](https://github.com/thoughtbot/appraisal) gem to run
our [RSpec](https://www.relishapp.com/rspec/) test suite against multiple
versions of [Rails](http://rubyonrails.org/).

* The unit test suite can be run with `rake` (aliased to `rake spec:unit`).
* The integration test suite can be run with `rake spec:features`.

### License

The Honeybadger gem is MIT licensed. See the [LICENSE](https://raw.github.com/honeybadger-io/honeybadger-ruby/master/LICENSE) file in this repository for details.
