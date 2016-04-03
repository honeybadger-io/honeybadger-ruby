# Honeybadger for Ruby

[![Code Climate](https://codeclimate.com/github/honeybadger-io/honeybadger-ruby/badges/gpa.svg)](https://codeclimate.com/github/honeybadger-io/honeybadger-ruby)
[![Test Coverage](https://codeclimate.com/github/honeybadger-io/honeybadger-ruby/badges/coverage.svg)](https://codeclimate.com/github/honeybadger-io/honeybadger-ruby)
[![Build Status](https://secure.travis-ci.org/honeybadger-io/honeybadger-ruby.png?branch=master)](http://travis-ci.org/honeybadger-io/honeybadger-ruby)
[![Gem Version](https://badge.fury.io/rb/honeybadger.png)](http://badge.fury.io/rb/honeybadger)

This is the notifier gem for integrating apps with the :zap: [Honeybadger Exception Notifier for Ruby and Rails](http://honeybadger.io).

When an uncaught exception occurs, Honeybadger will POST the relevant data to the Honeybadger server specified in your environment.

## Supported Ruby versions

| Ruby Interpreter  | Supported Version  |
| ----              | ----               |
| MRI               | >= 1.9.3          |
| JRuby             | >= 1.7 (1.9 mode) |
| Rubinius          | >= 2.0            |

## Supported web frameworks

| Framework     | Version       | Native?    |
| ------------- | ------------- |------------|
| Rails         | >= 3.0        | yes        |
| Sinatra       | >= 1.2.1      | yes        |
| Rack          | >= 1.0        | middleware |

Rails and Sinatra are supported natively (install/configure the gem and you're done). For vanilla Rack apps, we provide a collection of middleware that must be installed manually.

To use Rails 2.x, you'll need to use an earlier version of the Honeybadger gem. [Go to version 1.x of the gem docs](https://github.com/honeybadger-io/honeybadger-ruby/blob/1.16-stable/docs/index.md). 

Integrating with other libraries/frameworks is simple! [See the documentation](http://rubydoc.info/gems/honeybadger/) to learn about our public API, and see [Contributing](#contributing) to suggest a patch.

## Supported job queues

| Framework     | Version       | Native?      |
| ------------- | ------------- | ------------ |
| Sidekiq       | any           | yes          |
| Resque        | any           | yes          |
| Delayed Job   | any           | yes          |
| Sucker Punch  | any           | yes          |

You can integrate honeybadger into any Ruby script via the `Honeybadger.notify` method. 

## Getting Started

Honeybadger works out of the box with all popular Ruby frameworks. Installation is just a matter of including the gem and setting your API key. In this section, we'll cover the basics. More advanced installations are covered later. 

### 1. Install the gem


The first step is to add the honeybadger gem to your Gemfile:

```ruby
gem 'honeybadger'
```

Tell bundler to install:

```bash
$ bundle install
```

### 2. Set your API key

Next, you'll set the API key for this project.

```bash
$ bundle exec honeybadger install [YOUR API KEY HERE]
```

This will generate a `config/honeybadger.yml` file. If you don't like config files, you can place your API key in the `$HONEYBADGER_API_KEY` environment variable.

#### Heroku installation

If your app is deployed to heroku, you can configure Honeybadger on your dynos like so:

```bash
$ bundle exec honeybadger heroku install [YOUR API KEY HERE]
```

This will automatically add a `HONEYBADGER_API_KEY` environment variable to your
remote Heroku config and configure deploy notifications.

This step isn't necessary if you're using our [Heroku add-on](https://elements.heroku.com/addons/honeybadger).

### 3. Set up your code

#### Rails

You're done! Any rake tasks and job queues that load the Rails environment are also covered. 

For more info, check out our screencast on getting up and running with Honeybadger and Rails:

[![Using the Honeybadger gem with Rails](https://embed-ssl.wistia.com/deliveries/e1e2133b8f1bec224c57f6677f6bdb11691b3822.jpg?image_play_button=true&image_play_button_color=7b796ae0&image_crop_resized=150x84)](https://honeybadger.wistia.com/medias/l3cmyucx8f)

#### Sinatra

All you need to do is to include the honeybadger gem: 

```ruby
# Always require Sinatra first.
require 'sinatra'
# Then require honeybadger.
require 'honeybadger'
# Define your application code *after* Sinatra *and* honeybadger:
get '/' do
  raise "Sinatra has left the building"
end
```

To see an example of a sinatra implementation, check out this video:

[![Using the Honeybadger gem with Sinatra](https://embed-ssl.wistia.com/deliveries/7c9b6e6831f2288874f24d10eec88116e9f378eb.jpg?image_play_button=true&image_play_button_color=7b796ae0&image_crop_resized=150x84)](https://honeybadger.wistia.com/medias/b2wr5n9fcv)

#### Rack

With rack, you have to do things manually, but it's still just a few lines of code:

```ruby
require 'rack'
 
# Load the gem
require 'honeybadger'
 
# Write your app
app = Rack::Builder.app do
  run lambda { |env| raise "Rack down" }
end
 
# Configure and start Honeybadger
honeybadger_config = Honeybadger::Config.new(env: ENV['RACK_ENV'])
Honeybadger.start(honeybadger_config)
 
# And use Honeybadger's rack middleware
use Honeybadger::Rack::ErrorNotifier, honeybadger_config
use Honeybadger::Rack::MetricsReporter, honeybadger_config
 
run app
```




## Advanced Configuration

There are a few ways to configure the Honeybadger gem. You can use a YAML config file. You can use environment variables. Or you can use a combination of the two. 

We put together a short video highligting a few of the most common configuration options:

[![Advanced Honeybadger Gem Usage](https://embed-ssl.wistia.com/deliveries/5fccf29d2b27d0f7ec62b5b39e2f5d9cd1f6f5b7.jpg?image_play_button=true&image_play_button_color=7b796ae0&image_crop_resized=150x84)](https://honeybadger.wistia.com/medias/vv9qq9x39d)


### YAML Configuration File

By default, Honeybadger looks for a `honeybadger.yml` configuration file in the root of your project, and then `config/honeybadger.yml` (in that order). 

Here's what the simplest config file looks like:

```yaml
---
api_key: "my_api_key"
```

#### Nested Options

Some configuration options are written in YAML as nested hashes. For example, here's what the `logging.path` and `request.filter_keys` options look like in YAML:

```yaml
---
logging:
  path: "/path/to/honeybadger.log" 
request:
  filter_keys:
    - "credit_card"
```

#### Environments

Environment-specific options can be set by name-spacing the options beneath the environment name. For example:

```yaml
---
api_key: "my_api_key"
production:
  logging:
    path: "/path/to/honeybadger.log"
    level: "WARN"
```

#### ERB and Regex

The configuration file is rendered using ERB. That means you can set configuration options programmatically. You can also include regular expressions. Here's what that looks like:

```yaml
---
api_key: "<%= MyApplication.config.api_key %>"
request:
  filter_keys:
    - !ruby/regexp '/credit_card/i'
```

### Configuring with Environment Variables (12-factor style)

All configuration options can also be read from environment variables (ENV). To do this, uppercase the option name, replace all non-alphanumeric characters with underscores, and prefix with `HONEYBADGER_`. For example, `logging.path` becomes `HONEYBADGER_LOGGING_PATH`:

```
export HONEYBADGER_LOGGING_PATH=/path/to/honeybadger.log
```

ENV options override other options read from framework or `honeybadger.yml` sources, so both can be used together. 

## Configuration Options

You can use any of the options below in your config file, or in the environment. 



|Option                           | Type    | Description |
|-------------------------------- | ------- | ----------- |
|`api_key`                        | String  | The API key for your Honeybadger project.<br/>_Default: `nil`_|
|`env`                            | String  | The environment the app is running in. In Rails this defaults to `Rails.env`.<br/>_Default: `nil`_|
|`report_data`                    | Boolean | Enable/disable reporting of data. Defaults to false for "test", "development", and "cucumber" environments.  <br>_Default: `true`_|
|`root`                           | String  | The project's absolute root path.<br/>_Default: `Dir.pwd`_|
|`hostname`                       | String  | The hostname of the current box.<br/>_Default: `Socket.gethostname`_|
|`backend`                        | String  | An alternate backend to use for reporting data.<br/>_Default: `nil`_|
|`debug`                          | Boolean | Forces metrics and traces to be reported every 10 seconds rather than 60, and enables verbose debug logging.<br/>_Default: `false`_|
|`send_data_at_exit`              | Boolean | Finish sending enqueued exceptions and metrics data before allowing program to exit.<br/>_Default: `true`_|
|`disabled`                       | Boolean | Prevents Honeybadger from starting entirely.<br/>_Default: `false`_|
| `config_path`                   | String  | The path of the honeybadger config file. Can only be set via the `$HONEYBADGER_CONFIG_PATH` environment variable |
|`development_environments`       | Array   | Environments which will not report data by default (use report_data to enable/disable explicitly).<br/>_Default: `["development", "test", "cucumber"]`_|
|`plugins`                        | Array   | An optional list of plugins to load. Default is to load all plugins.<br/>_Default: `[]`_|
|`plugins.skip`                   | Array   | An optional list of plugins to skip.<br/>_Default: `[]`_|
|&nbsp;                           |         ||
|__LOGGING__                      |         ||
|`logging.path`                   | String  | The path (absolute, or relative from config.root) to the log file. Defaults to the rails logger or STDOUT. To log to standard out, use 'STDOUT'.<br/>_Default: `nil`_|
|`logging.level`                  | String  | The log level. Does nothing unless `logging.path` is also set.<br/>_Default: `INFO`_|
|&nbsp;                           |         ||
|__HTTP CONNECTION__              |         ||
|`connection.secure`              | Boolean | Use SSL when sending data.<br/>_Default: `true`_|
|`connection.host`                | String  | The host to use when sending data.<br/>_Default: `api.honeybadger.io`_|
|`connection.port`                | Integer | The port to use when sending data.<br/>_Default: `443`_|
|`connection.http_open_timeout`   | Integer | The HTTP open timeout when connecting to the server.<br/>_Default: `2`_|
|`connection.http_read_timeout`   | Integer | The HTTP read timeout when connecting to the server.<br/>_Default: `5`_|
|`connection.proxy_host`          | String  | The proxy host to use when sending data.<br/>_Default: `nil`_|
|`connection.proxy_port`          | Integer | The proxy port to use when sending data.<br/>_Default: `nil`_|
|`connection.proxy_user`          | String  | The proxy user to use when sending data.<br/>_Default: `nil`_|
|`connection.proxy_pass`          | String  | The proxy password to use when sending data.<br/>_Default: `nil`_|
|&nbsp;                           |         ||
|__REQUEST DATA FILTERING__       |         ||
|`request.filter_keys`            | Array   |  A list of keys to filter when sending request data. In Rails, this also includes existing params filters.<br/>*Default: `['password', 'password_confirmation']`*|
|`request.disable_session`        | Boolean | Prevent session from being sent with request data.<br/>_Default: `false`_|
|`request.disable_params`         | Boolean | Prevent params from being sent with request data.<br/>_Default: `false`_|
|`request.disable_environment`    | Boolean | Prevent Rack environment from being sent with request data.<br/>_Default: `false`_|
|`request.disable_url`            | Boolean | Prevent url from being sent with request data (Rack environment may still contain it in some cases).<br/>_Default: `false`_|
|&nbsp;                           |         ||
|__USER INFORMER__                |         ||
|`user_informer.enabled`          | Boolean | Enable the UserInformer middleware.  The user informer displays information about a Honeybadger error to your end-users when you display a 500 error page. This typically includes the error id which can be used to reference the error inside your Honeybadger account.  [Learn More](http://docs.honeybadger.io/article/48-show-users-a-unique-id-when-they-encounter-an-error)<br/>_Default: `true`_|
|`user_informer.info`             | String  | Replacement string for HTML comment in templates.<br/>*Default: `'Honeybadger Error {{error_id}}'`*|
|&nbsp;                           |         ||
|__USER FEEDBACK__                |         ||
|`feedback.enabled`               | Boolean | Enable the UserFeedback middleware. Feedback displays a comment form to your-end user when they encounter an error. When the user creates a comment, it is added to the error in Honeybadger, and a notification is sent.  [Learn More](http://docs.honeybadger.io/article/166-how-to-implement-a-custom-feedback-form)<br/>_Default: `true`_|
|&nbsp;                           |         ||
|__EXCEPTION REPORTING__          |         ||
|`exceptions.ignore`              | Array   | A list of exception class names to ignore (appends to defaults).<br/>_Default: `['ActiveRecord::RecordNotFound', 'ActionController::RoutingError', 'ActionController::InvalidAuthenticityToken', 'CGI::Session::CookieStore::TamperedWithCookie', 'ActionController::UnknownAction', 'AbstractController::ActionNotFound', 'Mongoid::Errors::DocumentNotFound Sinatra::NotFound']`_|
|`exceptions.ignore_only`         | Array   | A list of exception class names to ignore (overrides defaults).<br/>_Default: `[]`_|
|`exceptions.` `ignored_user_agents` | Array   | A list of user agents to ignore.<br/>_Default: `[]`_|
|`exceptions.rescue_rake`         | Boolean | Enable rescuing exceptions in rake tasks.<br/>_Default: `true` when run in background; `false` when run in terminal._|
|`exceptions.notify_at_exit`      | Boolean | Report unhandled exception when Ruby crashes (at\_exit).<br/>_Default: `true`._|
|`exceptions.source_radius`       | Integer | The number of lines before and after the source when reporting snippets.<br/>_Default: `2`_|
|`exceptions.local_variables`     | Boolean | Enable sending local variables. Requires the [binding_of_caller gem](https://rubygems.org/gems/binding_of_caller).<br/>_Default: `false`_|
|`exceptions.unwrap`              | Boolean | Reports #original_exception or #cause one level up from rescued exception when available.<br/>_Default: `false`_|
|&nbsp;                           |         ||
|__METRIC REPORTING__             |         ||
|`metrics.enabled`                | Boolean | Enable sending metrics, such as requests per minute.<br/>_Default: `true`_|
|`metrics.gc_profiler`            | Boolean | Enable sending GC metrics (GC::Profiler must be enabled)<br/>_Default: `false`_|
|&nbsp;                           |         ||
|__TRACE REPORTING__              |         ||
|`traces.enabled`                 | Boolean | Enable sending performance traces for slow actions.<br/>_Default: `true`_|
|`traces.threshold`               | Integer | The threshold in seconds to send traces.<br/>_Default: `2000`_|
|__SIDEKIQ__                      |         ||
|`sidekiq.attempt_threshold`      | Integer | The number of attempts before notifications will be sent.<br/>_Default: `0`_|
|`sidekiq.use_component`          | Boolean | Automatically set the component to the class of the job. Helps with grouping.<br/>_Default: `false`_|
|__DELAYED JOB__                  |         ||
|`delayed_job.attempt_threshold`  | Integer | The number of attempts before notifications will be sent.<br/>_Default: `0`_|
|__SINATRA__                        |         ||
|`sinatra.enabled`                | Boolean | Enable Sinatra auto-initialization.<br/>_Default: `true`_|

## Public Methods 

> What follows is a summary of the gem's most commonly-used public methods. For a more authoritative list, read the [full API documentation](http://www.rubydoc.info/gems/honeybadger/Honeybadger).


### `Honeybadger.context()`: Set metadata to be sent if an exception occurs

Sometimes, default exception data just isn't enough. If you have extra data that will help you in debugging, send it as part of an error's context. [View full method documentation](http://www.rubydoc.info/gems/honeybadger/Honeybadger%3Acontext)

#### Use this method if:

* You want to record the current user's id at the time of an exception
* You need to send raw POST data for use in debugging
* You have any other metadata you'd like to send with an exception


#### Examples:

```ruby
Honeybadger.context({my_data: 'my value'})

# Inside a Rails controller:
before_action do
  Honeybadger.context({user_id: current_user.id})
end

# Clearing global context:
Honeybadger.context.clear!
```
---


### `Honeybadger.notify()`: Send an exception to Honeybadger.

You normally won't have to use this method. Honeybadger detects and reports errors automatically in Rails and other popular frameworks. But there may be times when you need to manually control exception reporting. [View full method documentation](http://www.rubydoc.info/gems/honeybadger/Honeybadger%3Anotify)

#### Use this method if:

* You've rescued an exception, but still want to report it
* You need to report an exception outside of a supported framework. 
* You want complete control over what exception data is sent to us. 


#### Examples:

```ruby
# Sending an exception that you've already rescued
begin
  fail 'oops'
rescue => exception
  Honeybadger.notify(exception) 
end
```

---

### `Honeybadger.exception_filter()`: Programmatically ignore exceptions

This method lets you add a callback that will be run every time an exception is about to be reported to Honeybadger. If your callback returns a truthy value, the exception won't be reported. [View full method documentation](http://www.rubydoc.info/gems/honeybadger/Honeybadger%3Aexception_filter)

#### Use this method if:

* You need to ignore exceptions that meet complex criteria
* The built-in configuration options for filtering based on exception class and user agent aren't enough

#### Examples:

```ruby
# Here's how you might ignore exceptions based on their error message:
Honeybadger.exception_filter do |notice|
  notice[:error_message] =~ /sensitive data/
end
```

You can access any attribute on the `notice` argument by using the `[]` syntax. For a full list of attributes, see the [documentation for `Notice`](http://www.rubydoc.info/gems/honeybadger/Honeybadger/Notice#%5B%5D-instance_method) Here are a few examples to get you started:

```ruby
Honeybadger.exception_filter do |notice|
  notice[:exception].class < MyError &&
  notice[:params][:name] =~ "bob" &&
  notice[:context][:current_user_id] != 1
end
```
__WARNING:__ While it is possible to use this callback to modify the data that is reported to Honeybadger, this is not officially supported and may not be allowed in future versions of the gem.


## Deployment Tracking 

Honeybadger has an API to keep track of project deployments. Whenever you deploy, all errors for that environment will be resolved automatically. You can choose to enable or disable the auto-resolve feature from your Honeybadger project settings page.

### Capistrano Deployment Tracking

In order to track deployments using Capistrano, simply require Honeybadger's Capistrano task in your `Capfile`&nbsp;file:

```
require "capistrano/honeybadger"
```

If you ran the `honeybadger install` command in a project that was previously configured with Capistrano, we already added this for you.

Adding options to your&nbsp; _config/deploy.rb_&nbsp;file allows you to&nbsp;customize how the deploy task is executed. The syntax for setting them looks like this:

```
set :honeybadger_env, "preprod"
```

You can use any of the following options when configuring capistrano. 

| Option                    |      |
|-------------------------- | ---- |
|`honeybadger_user`         | Honeybadger will report the name of the local user who is deploying (using `whoami` or equivalent). Use this option to to report a different user.|
|`honeybadger_env`          | Honeybadger reports the environment supplied by capistrano by default. Use this option to change the reported environment.|
|`honeybadger_api_key`      | Honeybadger uses your configured API key by default. Use this option to override.|
|`honeybadger_async_notify` | Run deploy notification task asynchronously using `nohup`. True or False. Defaults to false.|
|`honeybadger_server`       | The api endpoint that receives the deployment notification.|
|`honeybadger`              | The name of the honeybadger executable. Default: "honeybadger"|


### Heroku Deployment Tracking

Deploy tracking via Heroku is implemented using Heroku's free [deploy hooks](https://devcenter.heroku.com/articles/deploy-hooks) addon. To install the addon and configure it for Honeybadger, run the following CLI command from your project root:

```
$ bundle exec honeybadger heroku install_deploy_notification
```

If the honeybadger CLI command fails for whatever reason, you can&nbsp;add the deploy hook manually by running:

```
$ heroku addons:add deployhooks:http --url="https://api.honeybadger.io/v1/deploys?deploy[environment]=production&deploy[local_username]={{user}}&deploy[revision]={{head}}&api_key=asdf" --app app-name
```

You should replace the api key and app-name with your own values. You may also want to change the environment (set to production by default).


### Deployment Tracking Via command line

We provide a CLI command to send deployment notifications manually:

```
bundle exec honeybadger deploy --environment=production
```

Run&nbsp; `bundle exec honeybadger help deploy` for all available options.



## Custom Error Pages

The Honeybadger gem has a few special tags that it looks for whenever you render an error page. These can be used to display extra information about the error, or to ask the user for information about how they triggered the error. 

### Displaying Error ID

When an error is sent to Honeybadger, our API returns a unique UUID for the occurrence within your project. This UUID can be automatically displayed for reference on Rails error pages (e.g. `public/500.html`) or any rack output by including the `Honeybadger::UserInformer` middleware.

To include the error id, simply place this magic HTML comment on your error page: 

```html
<!-- HONEYBADGER ERROR -->
```

By default, we will replace this tag with:

```
Honeybadger Error {{error_id}}
```

Where `{{error_id}}` is the UUID. You can customize this output by overriding the `user_informer.info` option in your honeybadger.yml file (you can also enabled/disable the middleware):

```yaml
user_informer:
  enabled: true
  info: "Error ID: {{error_id}}"
```

You can use that UUID to load the error at the site by going to&nbsp; [https://www.honeybadger.io/notice/UUID](https://www.honeybadger.io/notice/UUID).

### Collecting User Feedback

When an error is sent to Honeybadger, an HTML form can be generated so users can fill out relevant information that led up to that error. Feedback responses are displayed inline in the comments section on the fault detail page.

To include a user feedback form on your error page, simply add this magic HTML comment:

```html
<!-- HONEYBADGER FEEDBACK -->
```
You can change the text displayed in the form via the Rails internationalization system. Here's an example:

```yaml
# config/locales/en.yml
en:
  honeybadger:
    feedback:
      heading: "Care to help us fix this?"
      explanation: "Any information you can provide will help us fix the problem."
      submit: "Send"
      thanks: "Thanks for the feedback!"
      labels:
        name: "Your name"
        email: "Your email address"
        comment: "Comment (required)"
```

## Changelog

See https://github.com/honeybadger-io/honeybadger-ruby/blob/master/CHANGELOG.md

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
