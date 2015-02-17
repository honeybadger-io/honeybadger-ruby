* Exceptions with the same type but caused within different delayed jobs are not grouped together. They have their component and action set so that the application class name and excecuted action is displayed in the UI.

  *Panos Korros*

* All events logged within a delayed_job even those logged by Honeybadger.notify inherit the context of the delayed job and include the job_id, attempts, last_error and queue

  *Panos Korros*

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
