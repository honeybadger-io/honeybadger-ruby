Feature: Install the Gem in a Rails application

  Background:
    Given I generate a new Rails application
    And I configure the Honeybadger shim

  Scenario: Use the gem without vendoring the gem in a Rails application
    When I run the honeybadger generator with "-k myapikey"
    Then I should receive a Honeybadger notification
    And I should see the Rails version

  Scenario: Configure the notifier by hand
    When I configure my application to require Honeybadger
    And I configure the notifier to use "myapikey" as an API key
    And I run the honeybadger generator with ""
    Then I should receive a Honeybadger notification

  Scenario: Configuration within initializer isn't overridden by Railtie
    When I configure my application to require Honeybadger
    And I run the honeybadger generator with "-k myapikey"
    And I configure Honeybadger with:
      """
      config.api_key = "myapikey"
      config.project_root = "argle/bargle"
      """
    And I run `rake honeybadger:test`
    Then the output should contain "argle/bargle"

  Scenario: Try to install without an api key
    When I configure my application to require Honeybadger
    And I run the honeybadger generator with ""
    Then the output should contain "Must pass --api-key or --heroku or create config/initializers/honeybadger.rb"

  Scenario: Configure and deploy with Capistrano
    When I successfully run `capify .`
    And I configure my application to require Honeybadger
    And I run the honeybadger generator with "-k myapikey"
    And I run `cap -T`
    Then the output should contain "honeybadger:deploy"

  Scenario: Try to install when the honeybadger plugin still exists
    When I install the "honeybadger" plugin
    And I configure the notifier to use "myapikey" as an API key
    And I configure my application to require Honeybadger
    And I run the honeybadger generator with ""
    Then the output should contain "You must first remove the honeybadger plugin. Please run: script/plugin remove honeybadger"

  Scenario: Rescue an exception in a controller
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
      """
      config.api_key = 'myapikey'
      config.logger = Logger.new(STDOUT)
      """
    And I define a response for "TestController#index":
      """
      session[:value] = "test"
      raise RuntimeError, "some message"
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  Scenario: The app uses Vlad instead of Capistrano
    When I configure my application to require Honeybadger
    And I run `touch config/deploy.rb`
    And I run `rm Capfile`
    And I run the honeybadger generator with "-k myapikey"
    Then the file "config/deploy.rb" should not contain "capistrano"

  Scenario: Support the Heroku addon in the generator
    When I configure the Heroku gem shim with "myapikey"
    And I configure my application to require Honeybadger
    And I run the honeybadger generator with "--heroku"
    Then I should receive a Honeybadger notification
    And I should see the Rails version
    And my Honeybadger configuration should contain the following line:
      """
      config.api_key = ENV['HONEYBADGER_API_KEY']
      """

  Scenario: Support the --app option for the Heroku addon in the generator
    When I configure the Heroku gem shim with "myapikey" and multiple app support
    And I configure my application to require Honeybadger
    And I run the honeybadger generator with "--heroku -a myapp"
    Then I should receive a Honeybadger notification
    And I should see the Rails version
    And my Honeybadger configuration should contain the following line:
      """
      config.api_key = ENV['HONEYBADGER_API_KEY']
      """

  @wat
  Scenario: Filtering parameters in a controller
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
      """
      config.api_key = "myapikey"
      config.logger = Logger.new(STDOUT)
      config.params_filters << "credit_card_number"
      """
    And I define a response for "TestController#index":
      """
      params[:credit_card_number] = "red23"
      raise RuntimeError, "some message"
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  @wat
  Scenario: Filtering session in a controller
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
      """
      config.api_key = "myapikey"
      config.logger = Logger.new(STDOUT)
      config.params_filters << "secret"
      """
    And I define a response for "TestController#index":
      """
      session["secret"] = "blue42"
      raise RuntimeError, "some message"
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  @wat
  Scenario: Filtering session and params based on Rails parameter filters
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
      """
      config.api_key = 'myapikey'
      config.logger = Logger.new(STDOUT)
      """
    And I configure the application to filter parameter "secret"
    And I define a response for "TestController#index":
      """
      params["secret"] = "red23"
      session["secret"] = "blue42"
      raise RuntimeError, "some message"
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  Scenario: Notify honeybadger within the controller
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
      """
      config.api_key = 'myapikey'
      config.logger = Logger.new(STDOUT)
      """
    And I define a response for "TestController#index":
      """
      session[:value] = "test"
      notify_honeybadger(RuntimeError.new("some message"))
      render :nothing => true
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  Scenario: Notify honeybadger within a metal controller
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
      """
      config.api_key = 'myapikey'
      config.logger = Logger.new(STDOUT)
      """
    And I define a metal response for "TestController#index":
      """
      raise RuntimeError, "some message"
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  Scenario: Reporting 404s
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
    """
    config.api_key = 'myapikey'
    config.logger = Logger.new(STDOUT)
    config.ignore_only = []
    """
    And I perform a request to "http://example.com:123/this/route/does/not/exist"
    Then the output should contain "The page you were looking for doesn't exist."
    And I should receive a Honeybadger notification

  Scenario: Asynchronous delivery
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
      """
      config.api_key = 'myapikey'
      config.logger = Logger.new(STDOUT)
      config.async do |notice|
        handler = Thread.new do
          notice.deliver
        end
        handler.join
      end
      """
    And I define a response for "TestController#index":
      """
      raise RuntimeError, "some message"
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification
