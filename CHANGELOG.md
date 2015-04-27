* Fix bug when processing source extract for action_view templates.

  *Joshua Wood*

* Don't access secrets before Rails initialization.

  *Joshua Wood*

* Fix a bug which introduced a hard-dependency on Rack.

  *Joshua Wood*

* Fix a bug in ping where JSON was double-quoted.

  *Joshua Wood*

* Add support for honeybadger_user with Capistrano 2.

  *Nathan Fixler*

* Fixed a bug introduced in v2.0.8 which applied params filters to backtrace.

  *Joshua Wood*

* Fail gracefully when honeybadger.yml is empty or invalid.

  *Joshua Wood*

* Handle bad encodings in exception payloads.

  *Joshua Wood*

* Include full backtrace when logging worker exceptions.

  *Joshua Wood*

* Always send a test notice on install.

  *Joshua Wood*

* Send the id of the current process with error reports.

  *Joshua Wood*

* Don't sub partial project root in backtrace lines.

  *Joshua Wood*

* Merge exceptions.ignore config values with default ignored exception class
  names and add exceptions.ignore_only option to override.

  *Joshua Wood*

* Support for capistrano-rbenv gem in Capistrano task.

  *Chris Gunther*

* Support for capistrano-rvm gem in Capistrano task.

  *Kyle Rippey*

* Don't require honeybadger.yml to be writable when reading.

  *Joshua Wood*

* Detect ActionDispatch::TestProcess being included globally, fix issue locally,
  warn the user.

  *Joshua Wood*

* Fix a nil logger bug when a config error occurs.

  *Joshua Wood*

* Don't instrument metrics and traces in Rails when features are not available
  on account

  *Joshua Wood*

* Don't send error reports when disabled via configuration

  *Joshua Wood*
