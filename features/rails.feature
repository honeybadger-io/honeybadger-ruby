Feature: Install the Gem in a Rails application

  Background:
    Given I have built and installed the "honeybadger" gem
    And I generate a new Rails application

  Scenario: Use the gem without vendoring the gem in a Rails application
    When I configure the Honeybadger shim
    And I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with "-k myapikey"
    Then the command should have run successfully
    And I should receive a Honeybadger notification
    And I should see the Rails version

  Scenario: vendor the gem and uninstall
    When I configure the Honeybadger shim
    And I configure my application to require the "honeybadger" gem
    And I unpack the "honeybadger" gem
    And I run the honeybadger generator with "-k myapikey"
    Then the command should have run successfully
    When I uninstall the "honeybadger" gem
    And I install cached gems
    And I run "rake honeybadger:test"
    Then I should see "** [Honeybadger] Response from Honeybadger:"
    And I should receive two Honeybadger notifications

  Scenario: Configure the notifier by hand
    When I configure the Honeybadger shim
    And I configure the notifier to use "myapikey" as an API key
    And I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with ""
    Then I should receive a Honeybadger notification

  Scenario: Configuration within initializer isn't overridden by Railtie
    When I configure the Honeybadger shim
    And I configure usage of Honeybadger
    Then the command should have run successfully
    When I configure the notifier to use the following configuration lines:
      """
      config.api_key = "myapikey"
      config.project_root = "argle/bargle"
      """
    And I define a response for "TestController#index":
      """
      session[:value] = "test"
      raise RuntimeError, "some message"
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  Scenario: Try to install without an api key
    When I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with ""
    Then I should see "Must pass --api-key or --heroku or create config/initializers/honeybadger.rb"

  Scenario: Configure and deploy using only installed gem
    When I run "capify ."
    And I configure the Honeybadger shim
    And I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with "-k myapikey"
    And I configure my application to require the "capistrano" gem if necessary
    And I run "cap -T"
    Then I should see "honeybadger:deploy"

  Scenario: Configure and deploy using only vendored gem
    When I run "capify ."
    And I configure the Honeybadger shim
    And I configure my application to require the "honeybadger" gem
    And I unpack the "honeybadger" gem
    And I run the honeybadger generator with "-k myapikey"
    And I uninstall the "honeybadger" gem
    And I install cached gems
    And I configure my application to require the "capistrano" gem if necessary
    And I run "cap -T"
    Then I should see "honeybadger:deploy"

  Scenario: Try to install when the honeybadger plugin still exists
    When I install the "honeybadger" plugin
    And I configure the Honeybadger shim
    And I configure the notifier to use "myapikey" as an API key
    And I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with ""
    Then I should see "You must first remove the honeybadger plugin. Please run: script/plugin remove honeybadger"

  Scenario: Rescue an exception in a controller
    When I configure the Honeybadger shim
    And I configure usage of Honeybadger
    And I define a response for "TestController#index":
      """
      session[:value] = "test"
      raise RuntimeError, "some message"
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  Scenario: The gem should not be considered a framework gem
    When I configure the Honeybadger shim
    And I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with "-k myapikey"
    And I run "rake gems"
    Then I should see that "honeybadger" is not considered a framework gem

  Scenario: The app uses Vlad instead of Capistrano
    When I configure the Honeybadger shim
    And I configure my application to require the "honeybadger" gem
    And I run "touch config/deploy.rb"
    And I run "rm Capfile"
    And I run the honeybadger generator with "-k myapikey"
    Then "config/deploy.rb" should not contain "capistrano"

  Scenario: Support the Heroku addon in the generator
    When I configure the Honeybadger shim
    And I configure the Heroku rake shim
    And I configure the Heroku gem shim with "myapikey"
    And I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with "--heroku"
    Then the command should have run successfully
    And I should receive a Honeybadger notification
    And I should see the Rails version
    And my Honeybadger configuration should contain the following line:
      """
      config.api_key = ENV['HONEYBADGER_API_KEY']
      """

  Scenario: Support the --app option for the Heroku addon in the generator
    When I configure the Honeybadger shim
    And I configure the Heroku rake shim
    And I configure the Heroku gem shim with "myapikey" and multiple app support
    And I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with "--heroku -a myapp"
    Then the command should have run successfully
    And I should receive a Honeybadger notification
    And I should see the Rails version
    And my Honeybadger configuration should contain the following line:
      """
      config.api_key = ENV['HONEYBADGER_API_KEY']
      """

  Scenario: Filtering parameters in a controller
    When I configure the Honeybadger shim
    And I configure usage of Honeybadger
    When I configure the notifier to use the following configuration lines:
      """
      config.api_key = "myapikey"
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

  Scenario: Filtering session in a controller
    When I configure the Honeybadger shim
    And I configure usage of Honeybadger
    When I configure the notifier to use the following configuration lines:
      """
      config.api_key = "myapikey"
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

  Scenario: Filtering session and params based on Rails parameter filters
    When I configure the Honeybadger shim
    And I configure usage of Honeybadger
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
    When I configure the Honeybadger shim
    And I configure usage of Honeybadger
    And I define a response for "TestController#index":
      """
      session[:value] = "test"
      notify_honeybadger(RuntimeError.new("some message"))
      render :nothing => true
      """
    And I route "/test/index" to "test#index"
    And I perform a request to "http://example.com:123/test/index?param=value"
    Then I should receive a Honeybadger notification

  Scenario: Reporting 404s
    When I configure the Honeybadger shim
    And I configure usage of Honeybadger
    And I configure the notifier to use the following configuration lines:
    """
    config.ignore_only = []
    """
    And I perform a request to "http://example.com:123/this/route/does/not/exist"
    Then I should see "The page you were looking for doesn't exist."
    And I should receive a Honeybadger notification
