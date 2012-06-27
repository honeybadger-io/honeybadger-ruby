Feature: Rescue errors in Rails middleware

  Background:
    Given I have built and installed the "honeybadger" gem
    And I generate a new Rails application
    And I configure the Honeybadger shim
    And I configure my application to require the "honeybadger" gem
    And I run the honeybadger generator with "-k myapikey"

  Scenario: Rescue an exception in the dispatcher
    When I define a Metal endpoint called "Exploder":
      """
      def self.call(env)
        raise "Explode"
      end
      """
    When I perform a request to "http://example.com:123/metal/index?param=value"
    Then I should receive a Honeybadger notification
