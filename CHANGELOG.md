## Honeybadger 1.16.6 ##

* Fix cap3 bug where app server is not found for deploy notification.

  *Joshua Wood*

## Honeybadger 1.16.5 ##

* Add `delayed_job_attempt_threshold` configuration variable. Notifications will not be sent until this threshold is reached.

  *Tadas Tamosauskas*

* Ignore ActionController::UnknownFormat by default.
  
  *Sergey Rezvanov*

## Honeybadger 1.16.4 ##

* Include a portion of longer queries with traces.

  *Benjamin Curtis*

* Aggregate short queries when sending traces.

  *Benjamin Curtis*

## Honeybadger 1.16.3 ##

* Handle `nil` session in Rails controllers (i.e., when the `session_off` gem is
  enabled).

  *Joshua Wood*

* Add `unwrap_exceptions` configuration option; when `false`, exceptions will
  not be unwrapped (default: `true`).

  *Joshua Wood*

* Prevent `binding_of_caller` from being loaded automatically (requires
  `send_local_variables == true`).

  *Joshua Wood*

## Honeybadger 1.16.2 ##

* Fix a bug where #match was called on nil when instrumenting Net::HTTP
  requests.

  *Benjamin Curtis*

## Honeybadger 1.16.1 ##

* Add debug logging of successful ping responses.

  *Joshua Wood*

* Don't log when metrics/traces are disabled by service.

  *Joshua Wood*

## Honeybadger 1.16.0 ##

* Compress requests using deflate.

  *Joshua Wood*

* Fix a bug where context wasn't reported from Sinatra applications

  *Gavin Stark*

* Fix a bug which affected Rails 3.0 apps
  (`ActiveRecord::Base.connection_config` missing).

  *Joshua Wood*

* Stop sending non-server env.

  *Joshua Wood*

* Automatically fork worker when Unicorn forks (removes the need to call
  `Honeybadger::Monitor.worker.fork` in Unicorn's `after_fork` block.)

  *Joshua Wood*

* Ruby 1.8.7 and 1.9.2 are no longer supported.

  *Joshua Wood*

## Honeybadger 1.15.3 ##

* Send User-Agent header

  *Joshua Wood*

* Fix a bug where metrics were not reported for Passenger processes.

  *Joshua Wood*

## Honeybadger 1.15.2 ##

* Fix bug where honeybadger/monitor wasn't included in non-Rails apps, even
  though certain other integrations depend on it.

  *Joshua Wood*

## Honeybadger 1.15.1 ##

* Fix bug in Thor integration (Issue #74)

  *Joshua Wood*

## Honeybadger 1.15.0 ##

* Send traces for slow requests.

  *Benjamin Curtis*

## Honeybadger 1.14.0 ##

* Catch exceptions in Thor tasks.

  *Ryan Sonnek*

* Add option to send local_variables when binding_of_caller is
  installed. In order to enable it, the gem must be present in the
  project, and `config.send_local_variables` must be `true`.

  *Joshua Wood*

* Create Honeybadger::Rack namespace and add deprecation warnings for
  old middleware.

  *Joshua Wood*

* Support ruby 2.1 with Exception#cause

  *Ravil Bayramgalin*

* Add support for 3rd-party integrations via dependency injection.

  *Joshua Wood*

* Delayed Job support

  *Joshua Wood*

## Honeybadger 1.13.2 ##

* Fix 2 bugs where the Rails raises exceptions when accessing session
  information. (ActionDispatch::Session::SessionRestoreError) and
  ArgumentError when `config.secret_token` is missing.

  *Joshua Wood*

* Disable notices via API when unauthorized.

  *Joshua Wood*

## Honeybadger 1.13.1 ##

* Be less verbose when logging that metrics are disabled. (primarily for
Unicorn users)

  *Joshua Wood*

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
