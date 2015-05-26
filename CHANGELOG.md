* Trim all sanitized strings to 2k.

  *Joshua Wood*

* Add events to instrumented traces (i.e. in background jobs).

  *Joshua Wood*

* Restart workers once per hour when shutdown due to 40x.

  *Joshua Wood*

* Fix a tracing issue with net/http requests.

  *Joshua Wood*

* Send request data with traces.

  *Joshua Wood*

* Ditch per-controller metrics and add render_partial event to traces.

  *Benjamin Curtis*

* Disable local variables when BetterErrors is detected.

  *Joshua Wood*

* Exit with 1 from deploy command when request fails but ignore the failures in
  the capistrano task.

  *Joshua Wood*

* Support Resque natively.

  *Joshua Wood*

* Configure sidekiq.attempt_threshold to suppress notifications until retry
  threshold is reached.

  *Joshua Wood*

* Prevent Sinatra from using the same middleware more than once and add
  sinatra.enabled setting (default true) to disable auto-initialization
  of Sinatra.

  *Joshua Wood*

* Update default ignored exceptions to include the latest Rails rescue
  responses. (see issue #107)

  *Joshua Wood*

* Fix bug when processing source extract for action_view templates.

  *Joshua Wood*

* Exceptions with the same type but caused within different delayed jobs are not grouped together. They have their component and action set so that the application class name and excecuted action is displayed in the UI.

  *Panos Korros*

* All events logged within a delayed_job even those logged by Honeybadger.notify inherit the context of the delayed job and include the job_id, attempts, last_error and queue

  *Panos Korros*

* Catch Errno::ENFILE when reading system stats.

  *Dmitry Polushkin*

* Use explicit types for config options when casting from ENV.

  *Joshua Wood*

* Add exceptions.unwrap to config.

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
