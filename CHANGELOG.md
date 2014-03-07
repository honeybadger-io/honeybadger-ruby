## Honeybadger 1.13.0 ##

* Add native support for Sidekiq 3.0

  *Joshua Wood*

* Clean action_dispatch.request.parameters from payload.

  *Joshua Wood*

## Honeybadger 1.12.0 (skipped) ##

## Honeybadger 1.11.2 ##

* Fix Bundler::RubyVersionMismatch error when invoking heroku command
  from within Bundler.

  *Joshua Wood*

## Honeybadger 1.11.1 ##

* Add option to log the exception locally when the API cannot be
  reached.

  *Justin Mazzi*

## Honeybadger 1.11.0 ##

* Filter params from query strings in rack env.

  *Joshua Wood*

* Add I18n support to feedback form

  *Joshua Wood*

* Allow feedback template to be overridden.

  *Joshua Wood*

* Add feedback to Rails 2.3.x (also adds ping for Rails 2)

  *Joshua Wood*

* Capistrano 3 support

  *Joshua Wood*

## Honeybadger 1.10.3 ##

* Fixed bug with missing stddev stats

  *Ben Curtis*

* Fix concurrency race condition when modifying metrics hash

  *Joshua Wood*

* Fix a JRuby memory leak

  *Kevin Menard*

## Honeybadger 1.10.2 ##

* Explictly cast division to float.

  If you include mathn, a Rational is returned from #/, so we need
  to explictly cast to a float.

  *Austen Ito*

## Honeybadger 1.10.1 ##

* Stop sending ENV with rake exceptions

  *Joshua Wood*

## Honeybadger 1.10.0 ##

* Collect user feedback when an error occurs.

  *Joshua Wood*

* Remove Faraday dependency (restore net/http code)

  *Joshua Wood*

* Added params filtering by regex

  *Octavian Neamtu*

* Bring back the UserInformer

  *Joshua Wood*

* Allow API key to be overridden by notice.

  *Joshua Wood*

* Filter query strings.

  *Joshua Wood*

## Honeybadger 1.9.5 ##

* Call through middleware stack when disabling better_errors in test
  task (fixes incorrect error notification bug).

  *Joshua Wood*

* Fix test rake task/rack-mini-profiler bug where it requires an IP
  address to identify users.

  *Joshua Wood*

## Honeybadger 1.9.4 ##

* Fix bug where Faraday was getting a duplicate adapter when building
  client.

  *Joshua Wood*

## Honeybadger 1.9.3 ##

* Lock gemspec to faraday ~>0.7 to fix yield discrepancy between 0.7 and
  0.8.

  *Joshua Wood*

## Honeybadger 1.9.2 ##

* Fix bug causing Honeybadger#Sender to omit proxy configuration.

  *Joshua Wood*

## Honeybadger 1.9.0 ##

* Move from TestUnit/shoulda to RSpec.

  *Joshua Wood*

* Added metrics reporting

  *Benjamin Curtis*

* Added ping to Honeybadger on startup

  *Benjamin Curtis*

## Honeybadger 1.8.1 ##

* notify_honeybadger_or_ignore method for controllers

  *Pierre Olivier Martel*

## Honeybadger 1.8.0 ##

* Report memory and load stats

  *Benjamin Curtis*

* Use HONEYBADGER_API_KEY as default value for api_key

  *Benjamin Curtis*

* Prefer notice args to exception attributes

  *Joshua Wood*

* Trim size of notice message to 1k

  *Joshua Wood*

* Make hostname overridable in configuration.

  *Joshua Wood*

## Honeybadger 1.7.0 ##

* Added a custom grouping option

  *Joshua Wood*

* Added option to run capistrano deploy notification asynchronously 

 *Sergey Efremov*

## Honeybadger 1.6.2 ##

* Fail gracefully when Rack params cannot be parsed

  *Joshua Wood*

## Honeybadger 1.6.1 ##

* Fixes a bug in Rails 4 test task

  *Joshua Wood*

* Added a deploy rake task which always loads the Rails environment.
  Also added ability to override rake task in Capistrano recipe.

  *Joshua Wood*

## Honeybadger 1.6.0 ##

* Rescue from load error when application_controller.rb is missing.

  *Joshua Wood*

* Default to debug log level instead of info for general logging.

  *Joshua Wood*

* Ignore error classes by regexp, ignore subclasses of ignored classes

  *Joshua Wood*

* Detect and disable better_errors gem in Rails 3 test task

  *Joshua Wood*

* Add option to send session data (or not)

  *Joshua Wood*

* Send language in notice payload

  *Joshua Wood*

* Disable Rack::SSL middleware in Rails 3 test task. Rails'
  config.force_ssl setting otherwise prevents the request from reaching
  the controller.

  *Joshua Wood*

* Added a Changelog :)

  *Joshua Wood*

* Added deploy tracking documentation

  *Joshua Wood*

* Remove dependency on ActiveSupport

  *Pieter van de Bruggen*

* Rails 4 support

  *Joshua Wood*
