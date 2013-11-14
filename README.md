Honeybadger
===============

[![Build Status](https://secure.travis-ci.org/honeybadger-io/honeybadger-ruby.png?branch=master)](http://travis-ci.org/honeybadger-io/honeybadger-ruby)
[![Gem Version](https://badge.fury.io/rb/honeybadger.png)](http://badge.fury.io/rb/honeybadger)

This is the notifier gem for integrating apps with the :zap: [Honeybadger Exception Notifier for Ruby and Rails](http://honeybadger.io).

When an uncaught exception occurs, Honeybadger will POST the relevant data
to the Honeybadger server specified in your environment.

## Rails Installation

Add the Honeybadger gem to your gemfile:

```ruby
gem 'honeybadger'
```

Then generate the initializer:

    rails generate honeybadger --api-key <Your Api Key>

If you prefer to manually create the initializer, that's simple enough.
Just put the code below in `config/initializers/honeybadger.rb`

```ruby
Honeybadger.configure do |config|
  config.api_key = '[your-api-key]'
end
```

That's it!

### Rails 2.x

Add the honeybadger gem to your app. In `config/environment.rb`:

```ruby
config.gem 'honeybadger'
```

or if you are using bundler:

```ruby
gem 'honeybadger', :require => 'honeybadger/rails'
```

Then from your project's `RAILS_ROOT`, and in your development environment, run:

    rake gems:install
    rake gems:unpack GEM=honeybadger

As always, if you choose not to vendor the honeybadger gem, make sure
every server you deploy to has the gem installed or your application won't start.

Finally, create an initializer in `config/initializers` and configure your
API key for your project:

```ruby
  require 'honeybadger/rails'
  Honeybadger.configure do |config|
    config.api_key = '[your-api-key]'
  end
```

## Rack

In order to use honeybadger in a non-Rails rack app, just load
honeybadger, configure your API key, and use the Honeybadger::Rack
middleware:

```ruby
require 'rack'
require 'honeybadger'

Honeybadger.configure do |config|
  config.api_key = 'my_api_key'
end

app = Rack::Builder.app do
  run lambda { |env| raise "Rack down" }
end

use Honeybadger::Rack
run app
```

## Sinatra

Using honeybadger in a Sinatra app is just like a Rack app:

```ruby
require 'sinatra'
require 'honeybadger'

Honeybadger.configure do |config|
  config.api_key = 'my api key'
end

use Honeybadger::Rack

get '/' do
  raise "Sinatra has left the building"
end
```

## Additional integrations:

* [Catch exceptions in Resque jobs](https://github.com/henrik/resque-honeybadger)
* [Sidekiq - Simple, efficient message processing for Ruby](https://github.com/mperham/sidekiq) (supports Honeybadger natively)
* [DelayedJob](https://github.com/honeybadger-io/delayed_job_honeybadger)

## Usage

For the most part, Honeybadger works for itself.

It intercepts the exception middleware calls, sends notifications and continues the middleware call chain.

If you want to log arbitrary things which you've rescued yourself from a
controller, you can do something like this:

```ruby
# ...
rescue => ex
  notify_honeybadger(ex)
  flash[:failure] = 'Encryptions could not be rerouted, try again.'
end
# ...
```

The `#notify_honeybadger` call will send the notice over to Honeybadger for later
analysis. While in your controllers you use the `notify_honeybadger` method, anywhere
else in your code, use `Honeybadger.notify`. If you do not want [exception filters](#filtering)
to be skipped, use `notify_honeybadger_or_ignore` and `Honeybadger.notify_or_ignore` instead.


To perform custom error processing after Honeybadger has been notified, define the
instance method `#rescue_action_in_public_without_honeybadger(exception)` in your
controller.

You can test that Honeybadger is working in your production environment by using
this rake task (from RAILS_ROOT):

    rake honeybadger:test

If everything is configured properly, that task will send a notice to Honeybadger
which will be visible immediately.

## Ignored environments

Please note that in development mode, Honeybadger will **not** be
notified of exceptions that occur, except when running the test rake
task. The following environments are ignored by default: *development*,
*test*, and *cucumber*. You can modify which environments are ignored by
setting the `development_environments` option in your Honeybadger
initializer:

```ruby
Honeybadger.configure do |config|
  # ...
  # To add an additional environment to be ignored:
  config.development_environments << 'staging'

  # To override the default environments completely:
  config.development_environments = ['test', 'cucumber']
end
```

If you choose to override the `development_environments` option for
whatever reason, please make sure your test environments are ignored.

## Sending custom data

Honeybadger allows you to send custom data using `Honeybadger.context`.
Here's an example of sending some user-specific information in a Rails
`before_filter` call:

```ruby
before_filter do
  Honeybadger.context({
    :user_id => current_user.id,
    :user_email => current_user.email
  }) if current_user
end
```

Now, whenever an error occurs, Honeybadger will display the affected
user's id and email address, if available.

Subsequent calls to `context` will merge the existing hash with any new
data, so you can effectively build up context throughout your
request's life cycle. Honeybadger will discard the data when a
request completes, so that the next request will start with a blank
slate.

## Custom error grouping

By default, we group errors by error class, component (aka controller), and the application trace.

If you want to use your own grouping strategy,
you can, using the `fingerprint` configuration option. When configured,
a custom fingerprint will be sent with each error notification, and
we'll use that for grouping errors instead of the default:

    Honeybadger.configure do |config|
      ...

      # See lib/honeybadger/notice.rb for the options that are available
      # on the notice object
      config.fingerprint do |notice|
        [notice[:error_class], notice[:component], notice[:backtrace].to_s].join(':')
      end

    end

You can also pass the fingerprint as a string when notifying Honeybadger
directly:

    Honeybadger.notify(StandardError.new('oh noes!'), :fingerprint => 'asdf')

The fingerprint can be any Ruby object that responds to #to_s, and will
be sent to Honeybadger as a SHA1 hash.


## Tracking deploys

Honeybadger has an API to keep track of project deployments. Whenever
you deploy, all errors for that environment will be resolved
automatically. You can choose to enable or disable the auto-resolve
feature from your Honeybadger project settings page.

We officially support deploy tracking using Capistrano and Heroku:

### Capistrano

In order to track deployments using Capistrano, simply require
Honeybadger's Capistrano task in your `config/deploy.rb` file:

```ruby
require 'honeybadger/capistrano'
```

If you ran the Honeybadger install generator in a project that was
previously configured with Capistrano, we already added this for you.

The Capistrano task will run our `rake honeybadger:deploy` task on
the server you are deploying to, so that it can correctly report
environment-related information. To override the task that is run, you
can set the `:honeybadger_deploy_task` in your *config/deploy.rb* file:

```ruby
# Loads Rails environment before executing normal deploy task
set :honeybadger_deploy_task, 'honeybadger:deploy_with_environment'
```

You can run deploy notification task asynchronously. 
Just add `:honeybadger_async_notify` in your *config/deploy.rb* file:

```ruby
set :honeybadger_async_notify, true
````

If you would prefer to notify Honeybadger locally without using rake,
check out our blog post: [Honeybadger and Capistrano: the metal way](http://honeybadger.io/blog/2012/10/06/honeybadger-and-capistrano/).


### Heroku

Deploy tracking via Heroku is implemented using Heroku's free [deploy
hooks](https://devcenter.heroku.com/articles/deploy-hooks) addon. To
install the addon and configure it for Honeybadger, run the following
rake task from your project root:

    rake honeybadger:heroku:add_deploy_notification APP=app-name

Don't forget to replace "app-name" with the name of your app on
Heroku. Or, if you want to add the deploy hook manually, run:

    heroku addons:add deployhooks:http --url="https://api.honeybadger.io/v1/deploys?deploy[environment]=production&api_key=asdf" --app app-name

You should replace the api key and app-name with your own values. You
may also want to change the environment (set to production by default).

### Via Rake

If you are using other frameworks/platforms, you can still notify us of
a deploy. We provide a rake task that uses ENV variables to report
environment information:

    # Skips loading the Rails environment if Rails and the honeybadger
    # initializer are detected
    rake honeybadger:deploy TO=production

    # Always loads the Rails environment
    rake honeybadger:deploy_with_environment TO=production

You can optionally add:

* `REPO=[scm repo url]`
* `REVISION=[scm sha]`
* `USER=[local user's name]`
* `API_KEY=[a different api key]`
* `DRY_RUN=true (simulates notification)`

## Notifying Honeybadger asynchronously

Want to send notices in a thread, or even use Resque or Sidekiq to
deliver notifications? The 'badger has you covered.

To get started, you'll need to configure Honeybadger to accept a
handler. A handler can be any object that responds to `#call` (usually a
`Proc`) and accepts one argument (a `Honeybadger::Notice` instance). The
handler can be set directly by setting the `async` configuration option,
or by passing a block to `config.async` (in this case, a Proc instance
will be created for you):

```ruby
Honeybadger.configure do |config|
  # ...

  # Configuring handler directly:
  config.async do |notice|
    # Delivers notification immediately
    notice.deliver # => 'qwer-asdf-zxcv'
  end

  # Using your own handler (identical behavior):
  config.async = Proc.new { |n| n.deliver }
end
```

We've left the implementation mostly up to you, but here are a few
examples of notifying Honeybadger asynchronously:

### Using thread

```ruby
Honeybadger.configure do |config|
  config.async do |notice|
    Thread.new { notice.deliver }
  end
end
```

### Using Resque

```ruby
Honeybadger.configure do |config|
  config.async do |notice|
    Resque.enqueue(WorkingBadger, notice.to_json)
  end
end

class WorkingBadger
  @queue = :cobra_alert

  def self.perform(notice)
    Honeybadger.sender.send_to_honeybadger(notice)
  end
end
```

### Using Sidekiq

```ruby
Honeybadger.configure do |config|
  config.async do |notice|
    WorkingBadger.perform_async(notice.to_json)
  end
end

class WorkingBadger
  include Sidekiq::Worker

  def perform(notice)
    Honeybadger.sender.send_to_honeybadger(notice)
  end
end
```

### Using GirlFriday

```ruby
COBRA_QUEUE = GirlFriday::WorkQueue.new(:honeybadger_notices, :size => 7) do |notice|
  notice.deliver
end

Honeybadger.configure do |config|
  config.async do |notice|
    COBRA_QUEUE.push(notice)
  end
end
```

## Going beyond exceptions

You can also pass a hash to `Honeybadger.notify` method and store whatever you want,
not just an exception. And you can also use it anywhere, not just in
controllers:

```ruby
begin
  params = {
    # params that you pass to a method that can throw an exception
  }
  my_unpredicable_method(*params)
rescue => e
  Honeybadger.notify(
    :error_class   => "Special Error",
    :error_message => "Special Error: #{e.message}",
    :parameters    => params
  )
end
```

While in your controllers you use the `notify_honeybadger` method, anywhere else in
your code, use `Honeybadger.notify`. Honeybadger will get all the information
about the error itself. As for a hash, these are the keys you should pass:

* `:error_class` - Use this to group similar errors together. When Honeybadger catches an exception it sends the class name of that exception object.
* `:error_message` - This is the title of the error you see in the errors list. For exceptions it is "#{exception.class.name}: #{exception.message}"
* `:parameters` - While there are several ways to send additional data to Honeybadger, passing a Hash as :parameters as in the example above is the most common use case. When Honeybadger catches an exception in a controller, the actual HTTP client request parameters are sent using this key.

Honeybadger merges the hash you pass with these default options:

```ruby
{
  :api_key       => Honeybadger.api_key,
  :error_message => 'Notification',
  :backtrace     => caller,
  :parameters    => {},
  :session       => {},
  :context       => {}
}
```

You can override any of those parameters.

### Sending shell environment variables when "Going beyond exceptions"

One common request we see is to send shell environment variables along with
manual exception notification.  We recommend sending them along with CGI data
or Rack environment (:cgi_data or :rack_env keys, respectively.)

See `Honeybadger::Notice#initialize` in
[lib/honeybadger/notice.rb](https://github.com/honeybadger-io/honeybadger-ruby/blob/master/lib/honeybadger/notice.rb)
for more details.

## Filtering

You can specify a whitelist of errors that Honeybadger will not report on. Use
this feature when you are so apathetic to certain errors that you don't want
them even logged.

This filter will only be applied to automatic notifications, not manual
notifications (when #notify is called directly).

Honeybadger ignores the following exceptions by default:

```ruby
ActiveRecord::RecordNotFound
ActionController::RoutingError
ActionController::InvalidAuthenticityToken
CGI::Session::CookieStore::TamperedWithCookie
ActionController::UnknownAction
AbstractController::ActionNotFound
Mongoid::Errors::DocumentNotFound
```

To ignore errors in addition to those, specify their names in your Honeybadger
configuration block. You may use a string, regexp, or class:

```ruby
Honeybadger.configure do |config|
  config.api_key      = '1234567890abcdef'
  config.ignore       << /IgnoredError$/
  config.ignore       << "ActiveRecord::IgnoreThisError"
  config.ignore       << OtherException
end
```

To ignore *only* certain errors (and override the defaults), use the #ignore_only attribute.

```ruby
Honeybadger.configure do |config|
  config.api_key      = '1234567890abcdef'
  config.ignore_only  = ["ActiveRecord::IgnoreThisError"] # or [] to ignore no exceptions.
end
```

Subclasses of ignored classes will also be ignored, while strings and
regexps are compared with the error class name only.

To ignore certain user agents, add in the #ignore_user_agent attribute as a
string or regexp:

```ruby
Honeybadger.configure do |config|
  config.api_key      = '1234567890abcdef'
  config.ignore_user_agent  << /Ignored/
  config.ignore_user_agent << 'IgnoredUserAgent'
end
```

To ignore exceptions based on other conditions, use #ignore_by_filter:

```ruby
Honeybadger.configure do |config|
  config.api_key      = '1234567890abcdef'
  config.ignore_by_filter do |exception_data|
    true if exception_data[:error_class] == "RuntimeError"
  end
end
```

To replace sensitive information sent to the Honeybadger service with [FILTERED] use #params_filters:

```ruby
Honeybadger.configure do |config|
  config.api_key      = '1234567890abcdef'
  config.params_filters << "credit_card_number"
end
```

You can also add a regex to filter out sensitive parameters:

```ruby
Honeybadger.configure do |config|
  config.api_key      = '1234567890abcdef'
  config.params_filters << /credit_card_number/
end
```

This is especially useful when your request parameters sometimes include search keys like
'credit_card_number_begins_with', 'credit_card_matches', etc. to exclude a whole class of parameters.

The param values for 'password' and 'password_confirmation' are always filtered out by default.

Note that, when rescuing exceptions within an ActionController method,
honeybadger will reuse filters specified by #filter_parameter_logging.

To disable sending session data:

```ruby
Honeybadger.configure do |config|
  config.api_key      = '1234567890abcdef'
  config.send_request_session = false
end
```

## Setting the hostname

The hostname for the local server is determined by `Socket.gethostname`
by default, but can be overridden using the `hostname` configuration
option:

```ruby
Honeybadger.configure do |config|
  # ...
  config.hostname = `hostname`
end
```

## Testing

When you run your tests, you might notice that the Honeybadger service is recording
notices generated using #notify when you don't expect it to. You can
use code like this in your test_helper.rb or spec_helper.rb files to redefine
that method so those errors are not reported while running tests.

```ruby
module Honeybadger
  def self.notify(exception, opts = {})
    # do nothing.
  end
end
```

## Proxy Support

The notifier supports using a proxy, if your server is not able to
directly reach the Honeybadger servers. To configure the proxy settings,
added the following information to your Honeybadger configuration block.

```ruby
Honeybadger.configure do |config|
  config.proxy_host = 'proxy.host.com'
  config.proxy_port = 4038
  config.proxy_user = 'foo' # optional
  config.proxy_pass = 'bar' # optional
end
```

## User Informer

When an error is sent to Honeybadger, our API returns a unique UUID for
the occurrence within your project. This UUID can be automatically
displayed for reference on Rails error pages (e.g. `public/500.html`) or
any rack output by including the `Honeybadger::UserInformer` middleware.

To include this output, you must reference a special tag within your
document or response body:

```html
<!-- HONEYBADGER ERROR -->
```

By default, we will replace this tag with:

```
Honeybadger Error {{error_id}}
```

Where `{{error_id}}` is the UUID. You can customize this output by
overriding the `user_information` option in your Honeybadger
initializer:

```ruby
Honeybadger.configure do |config|
  # ...
  config.user_information = "Error ID: {{error_id}}"
end
```

## Troubleshooting

By default, Honeybadger is quiet when your log level is set to INFO
(most production environments). If you would like to be notified via
logs when Honeybadger completes a successful notification, set the
`config.debug` option to true:

```ruby
Honeybadger.configure do |config|
  # ...
  config.debug = true
end
```

## Supported Ruby versions

Honeybadger supports Ruby 1.8.7 through 2.0.

## Supported Rails versions

Honeybadger supports Rails 2.3.14 through Rails 4.0.0.beta1.

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

## Credits

Original code based on the [airbrake](http://airbrake.io) gem,
originally by Thoughtbot, Inc.

Thank you to Thoughtbot and all of the Airbrake contributors!

The nifty custom data (`Honeybadger.context()`) feature was inspired by Exceptional.

## License

Honeybadger is Copyright 2013 © Honeybadger Industries LLC. It is free software, and
may be redistributed under the terms specified in the MIT-LICENSE file.
