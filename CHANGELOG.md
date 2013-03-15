## Honeybadger 1.7.0 (Unreleased) ##

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
