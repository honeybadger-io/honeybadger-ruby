Feature: Install the Gem in a Rails 3.x application

  Background:
    Given I generate a new Rails application
    And I configure the Honeybadger shim

  Scenario: Rails is missing `config.secret_token`
    When I configure my application to require Honeybadger
    And I configure Honeybadger with:
      """
      config.api_key = "myapikey"
      config.logger = Logger.new(STDOUT)
      config.debug = true
      """
    And I define a response for "TestController#index":
      """
      session["secret"] = "blue42"
      render :nothing => true
      """
    And I route "/test/index" to "test#index"
    And I successfully run `rm config/initializers/secret_token.rb`
    And I perform a request to "http://example.com:123/test/index"
    Then I should receive a Honeybadger notification
    And the request should not contain "blue42"
    And the request session should contain "config.secret_token"

