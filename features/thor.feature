Feature: Use the Gem to catch errors in a Thor application

  Scenario: Catching exceptions in Thor
    When I run thor with test:honeybadger
    Then I should receive a Honeybadger notification
