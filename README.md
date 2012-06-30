Honeybadger
===============

[![Build Status](https://secure.travis-ci.org/honeybadger-io/honeybadger-ruby.png?branch=master)](http://travis-ci.org/honeybadger-io/honeybadger-ruby)

This is the notifier gem for integrating apps with [Honeybadger](http://honeybadger.io).

When an uncaught exception occurs, Honeybadger will POST the relevant data
to the Honeybadger server specified in your environment.

## Rails Installation

Add the Honeybadger gem to your gemfile:

    gem 'honeybadger'

Create an initializer in config/initializers and configure your API key
for your project:

    # Uncomment the following line if running lower than Rails 3.2
    # require 'honeybadger/rails'
    Honeybadger.configure do |config|
      config.api_key = '[your-api-key]'
    end

That's it!

### Rails 2.x

Add the honeybadger gem to your app. In config/environment.rb:

    config.gem 'honeybadger'
    
or if you are using bundler:

    gem 'honeybadger', :require => 'honeybadger/rails'

Then from your project's RAILS_ROOT, and in your development environment, run:

    rake gems:install
    rake gems:unpack GEM=honeybadger

As always, if you choose not to vendor the honeybadger gem, make sure
every server you deploy to has the gem installed or your application won't start.

Finally, create an initializer in config/initializers and configure your
API key for your project:

    require 'honeybadger/rails'
    Honeybadger.configure do |config|
      config.api_key = '[your-api-key]'
    end

## Rack

In order to use honeybadger in a non-Rails rack app, just load
honeybadger, configure your API key, and use the Honeybadger::Rack
middleware:

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

## Sinatra

Using honeybadger in a Sinatra app is just like a Rack app:

    require 'sinatra'
    require 'honeybadger'

    Honeybadger.configure do |config|
      config.api_key = 'my api key'
    end

    use Honeybadger::Rack

    get '/' do
      raise "Sinatra has left the building"
    end

## Usage

For the most part, Honeybadger works for itself. 

It intercepts the exception middleware calls, sends notifications and continues the middleware call chain.

If you want to log arbitrary things which you've rescued yourself from a
controller, you can do something like this:

    ...
    rescue => ex
      notify_honeybadger(ex)
      flash[:failure] = 'Encryptions could not be rerouted, try again.'
    end
    ...

The `#notify_honeybadger` call will send the notice over to Honeybadger for later
analysis. While in your controllers you use the `notify_honeybadger` method, anywhere
else in your code, use `Honeybadger.notify`.

To perform custom error processing after Honeybadger has been notified, define the
instance method `#rescue_action_in_public_without_honeybadger(exception)` in your
controller.

You can test that Honeybadger is working in your production environment by using
this rake task (from RAILS_ROOT):

    rake honeybadger:test

If everything is configured properly, that task will send a notice to Honeybadger
which will be visible immediately.

## Going beyond exceptions

You can also pass a hash to `Honeybadger.notify` method and store whatever you want,
not just an exception. And you can also use it anywhere, not just in
controllers:

    begin
      params = {
        # params that you pass to a method that can throw an exception
      }
      my_unpredicable_method(params)
    rescue => e
      Honeybadger.notify(
        :error_class   => "Special Error",
        :error_message => "Special Error: #{e.message}",
        :parameters    => params
      )
    end

While in your controllers you use the `notify_honeybadger` method, anywhere else in
your code, use `Honeybadger.notify`. Honeybadger will get all the information
about the error itself. As for a hash, these are the keys you should pass:

* `:error_class` - Use this to group similar errors together. When Honeybadger catches an exception it sends the class name of that exception object.
* `:error_message` - This is the title of the error you see in the errors list. For exceptions it is "#{exception.class.name}: #{exception.message}"
* `:parameters` - While there are several ways to send additional data to Honeybadger, passing a Hash as :parameters as in the example above is the most common use case. When Honeybadger catches an exception in a controller, the actual HTTP client request parameters are sent using this key.

Honeybadger merges the hash you pass with these default options:

    {
      :api_key       => Honeybadger.api_key,
      :error_message => 'Notification',
      :backtrace     => caller,
      :parameters    => {},
      :session       => {}
    }

You can override any of those parameters.

### Sending shell environment variables when "Going beyond exceptions"

One common request we see is to send shell environment variables along with
manual exception notification.  We recommend sending them along with CGI data
or Rack environment (:cgi_data or :rack_env keys, respectively.)

See Honeybadger::Notice#initialize in lib/honeybadger/notice.rb for
more details.

## Filtering

You can specify a whitelist of errors that Honeybadger will not report on. Use
this feature when you are so apathetic to certain errors that you don't want
them even logged.

This filter will only be applied to automatic notifications, not manual
notifications (when #notify is called directly).

Honeybadger ignores the following exceptions by default:

    ActiveRecord::RecordNotFound
    ActionController::RoutingError
    ActionController::InvalidAuthenticityToken
    CGI::Session::CookieStore::TamperedWithCookie
    ActionController::UnknownAction
    AbstractController::ActionNotFound
    Mongoid::Errors::DocumentNotFound

To ignore errors in addition to those, specify their names in your Honeybadger
configuration block.

    Honeybadger.configure do |config|
      config.api_key      = '1234567890abcdef'
      config.ignore       << "ActiveRecord::IgnoreThisError"
    end

To ignore *only* certain errors (and override the defaults), use the #ignore_only attribute.

    Honeybadger.configure do |config|
      config.api_key      = '1234567890abcdef'
      config.ignore_only  = ["ActiveRecord::IgnoreThisError"] # or [] to ignore no exceptions.
    end

To ignore certain user agents, add in the #ignore_user_agent attribute as a
string or regexp:

    Honeybadger.configure do |config|
      config.api_key      = '1234567890abcdef'
      config.ignore_user_agent  << /Ignored/
      config.ignore_user_agent << 'IgnoredUserAgent'
    end

To ignore exceptions based on other conditions, use #ignore_by_filter:

    Honeybadger.configure do |config|
      config.api_key      = '1234567890abcdef'
      config.ignore_by_filter do |exception_data|
        true if exception_data[:error_class] == "RuntimeError"
      end
    end

To replace sensitive information sent to the Honeybadger service with [FILTERED] use #params_filters:

    Honeybadger.configure do |config|
      config.api_key      = '1234567890abcdef'
      config.params_filters << "credit_card_number"
    end

Note that, when rescuing exceptions within an ActionController method,
honeybadger will reuse filters specified by #filter_parameter_logging.

## Testing

When you run your tests, you might notice that the Honeybadger service is recording
notices generated using #notify when you don't expect it to. You can
use code like this in your test_helper.rb or spec_helper.rb files to redefine
that method so those errors are not reported while running tests.

    module Honeybadger
      def self.notify(exception, opts = {})
        # do nothing.
      end
    end

## Proxy Support

The notifier supports using a proxy, if your server is not able to
directly reach the Honeybadger servers. To configure the proxy settings,
added the following information to your Honeybadger configuration block.

    Honeybadger.configure do |config|
      config.proxy_host = proxy.host.com
      config.proxy_port = 4038
      config.proxy_user = foo # optional
      config.proxy_pass = bar # optional
    end

## Supported Rails versions

Honeybadger supports Rails 3.0.0 through rails 3.2.6.

## Credits

Original code based on the [airbrake](http://airbrake.io) gem,
originally by Thoughtbot, Inc.

Thank you to Thoughtbot and all of the Airbrake contributors!

## License

Honeybadger is Copyright 2012 © Honeybadger. It is free software, and
may be redistributed under the terms specified in the MIT-LICENSE file.
