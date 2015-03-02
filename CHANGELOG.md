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
