Feature: Rescue errors in Rails middleware

  Background:
    Given I generate a new Rails application
    And I configure the Honeybadger shim
    And I configure Honeybadger with:
      """
      config.api_key = 'myapikey'
      config.logger = Logger.new(STDOUT)
      """

  Scenario: Rescue an exception in the dispatcher
    When I define a Metal endpoint called "Exploder":
      """
      def self.call(env)
        raise "Explode"
      end
      """
    When I perform a request to "http://example.com:123/metal/index?param=value"
    Then I should receive a Honeybadger notification
