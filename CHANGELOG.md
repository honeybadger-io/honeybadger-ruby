# Change Log
All notable changes to this project will be documented in this file. See [Keep a
CHANGELOG](http://keepachangelog.com/) for how to update this file. This project
adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased][unreleased]

## [2.6.0] - 2016-04-22
### Added
- Automatically report unhandled exceptions at exit.
- Add `Honeybadger.get_context` method. -@homanchou

### Changed
- Filter Authorization header (HTTP\_AUTHORIZATION) by default.

### Fixed
- Always convert to string when sanitizing strings.
- Fix potential performance issue due to and `ensure` block. See #186.

## [2.5.3] - 2016-03-10
### Fixed
- Squashed a bug where the wrong source extract was sent for some instances of
  `ActionView::Template::Error`.

## [2.5.2] - 2016-03-08
### Fixed
- Allow plugin names in config to be symbols or strings (#177).
- Fix bug in resque-retry logic. -@davidguthu

## [2.5.1] - 2016-02-22
### Fixed
- Fix bug in resque-retry logic. -@davidguthu

## [2.5.0] - 2016-02-19
### Added
- Configuration option max\_queue_size for maximum worker queue size.
- Add `resque.resque_retry.send_exceptions_when_retrying` config option.
  -@davidguthu

## [2.4.1] - 2016-02-04
### Fixed
- Never send traces or metrics when disabled by plan or config.

## [2.4.0] - 2016-02-02
### Added
- [Sucker Punch](https://github.com/brandonhilkert/sucker_punch) support

## [2.3.3] - 2016-01-06
### Fixed
- Fixed a bug which caused a Passenger-related error message when booting a
  heroku console.

## [2.3.2] - 2015-12-15
### Fixed
- Be stricter when sanitizing recursive objects (allow only `Hash`, `Array`,
  `Set`).  This fixes a bug where some gems (such as the dropbox gem)
  monkeypatch `#to_hash` on `Array`.

## [2.3.1] - 2015-11-20
### Fixed
- Handle invalid utf8 in ActiveRecord SQL queries.

## [2.3.0] - 2015-11-12
### Added
- Rails 5 support.
- Support overriding TTY behavior in rake reporter.

### Fixed
- Capistrano 3 `undefined method `verbosity'` bugfix.
- Fixed "uninitialized constant Set" error when Set is not previously required.

## [2.2.0] - 2015-10-29
### Added
- Added a config option to automatically set the component to the class name of the
  Sidekiq job where an error originated. Causes errors to be grouped by worker
  in addition to class name/location.

### Fixed
- Always refresh capistrano revision during deploy notification.
- Support capistrano-chruby. -Kyle Rippey
- Send the wrapped class name for Sidekiq traces when using a wrapper such as
  ActiveJob.
- Performance tuning for Sidekiq plugin.

## [2.1.5] - 2015-09-23
### Fixed
- Apply parameter filters to local variables.

## [2.1.4] - 2015-09-02
### Fixed
- Support windows paths when loading plugins. -@aharpervc

## [2.1.3] - 2015-07-24
### Added
- Don't send empty local_variables in payload when disabled.
- Better logging of reason when API requests are denied.
- Truncate long queries in traces rather than tossing them.

### Fixed
- Missing vendor libs.

## [2.1.2][yanked]

## [2.1.1] - 2015-07-15
### Added
- Update heroku cli deprecations. -@adamkuipers
- Don't insert middleware if they're disabled. -Bradley Priest
- Don't send RAW_POST_DATA.
- Filter HTTP_COOKIE in request cgi_data. -Sam McTaggart
- Support for extracting the correct component & action for Rails Active Jobs
  (previously all Active Jobs where reported as
  'ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper'). -Panos Korros

### Fixed
- Fix breakage relating to Exceptions containing a :cause attribute which is not
  itself an Exception. -Gabe da Silveira

## [2.1.0] - 2015-06-04
### Added
- Add events to instrumented traces (i.e. in background jobs).
- Restart workers once per hour when shutdown due to 40x.
- Send request data with traces.
- Support Resque natively.
- Configure sidekiq.attempt_threshold to suppress notifications until retry
  threshold is reached.
- Add exceptions.unwrap to config.

### Changed
- Trim all sanitized strings to 2k.
- Ditch per-controller metrics and add render_partial event to traces. -Benjamin Curtis
- Exit with 1 from deploy command when request fails but ignore the failures in
  the capistrano task.
- Update default ignored exceptions to include the latest Rails rescue
  responses. (see issue #107)
- Exceptions with the same type but caused within different delayed jobs are not
  grouped together. They have their component and action set so that the
  application class name and excecuted action is displayed in the UI.  -Panos
  Korros
- All events logged within a delayed_job even those logged by Honeybadger.notify
  inherit the context of the delayed job and include the job_id, attempts,
  last_error and queue. -Panos Korros

### Fixed
- Allow API key to be overridden from `Honeybadger.notify`.
- Fix a tracing issue with net/http requests.
- Disable local variables when BetterErrors is detected.
- Prevent Sinatra from using the same middleware more than once and add
  sinatra.enabled setting (default true) to disable auto-initialization
  of Sinatra.
- Catch Errno::ENFILE when reading system stats. -Dmitry Polushkin
- Use explicit types for config options when casting from ENV.

## [2.0.12] - 2015-04-27
### Fixed
- Fix bug when processing source extract for action_view templates.

## [2.0.11] - 2015-04-02
### Fixed
- Don't access secrets before Rails initialization.
- Fix a bug which introduced a hard-dependency on Rack.

## [2.0.10] - 2015-03-24
### Added
- Add support for honeybadger_user with Capistrano 2. -Nathan Fixler

### Fixed
- Fix a bug in ping where JSON was double-quoted.

## [2.0.9] - 2015-03-15
### Fixed
- Fixed a bug introduced in v2.0.8 which applied params filters to backtrace.
- Fail gracefully when honeybadger.yml is empty or invalid.

## [2.0.8] - 2015-03-11
### Added
- Include full backtrace when logging worker exceptions.
- Always send a test notice on install.
- Send the id of the current process with error reports.

### Fixed
- Handle bad encodings in exception payloads.

## [2.0.7][yanked] - 2015-03-11

## [2.0.6] - 2015-02-16
### Fixed
- Don't sub partial project root in backtrace lines.

## [2.0.5] - 2015-02-12
### Added
- Merge exceptions.ignore config values with default ignored exception class
  names and add exceptions.ignore_only option to override.

## [2.0.4] - 2015-02-10
### Added
- Support for capistrano-rbenv gem in Capistrano task. -Chris Gunther

## [2.0.3] - 2015-02-10
### Fixed
- Support for capistrano-rvm gem in Capistrano task. -Kyle Rippey
- Don't require honeybadger.yml to be writable when reading.

## [2.0.2] - 2015-02-04
### Fixed
- Detect ActionDispatch::TestProcess being included globally, fix issue locally,
  warn the user.
- Fix a nil logger bug when a config error occurs.

## [2.0.1] - 2015-01-30
### Fixed
- Don't instrument metrics and traces in Rails when features are not available
  on account.
- Don't send error reports when disabled via configuration.
