Feature: Use the Gem to catch errors in a Rake application

  @pending
  Scenario: Catching exceptions in Rake
    When I run rake with honeybadger
    Then Honeybadger should catch the exception

  @pending
  Scenario: Falling back to default handler before Honeybadger is configured
    When I run rake with honeybadger not yet configured
    Then Honeybadger should not catch the exception

  @pending
  Scenario: Disabling Rake exception catcher
    When I run rake with honeybadger disabled
    Then Honeybadger should not catch the exception

  @pending
  Scenario: Autodetect, running from terminal
    When I run rake with honeybadger autodetect from terminal
    Then Honeybadger should not catch the exception

  @pending
  Scenario: Autodetect, not running from terminal
    When I run rake with honeybadger autodetect not from terminal
    Then Honeybadger should catch the exception

  @pending
  Scenario: Sending the correct component name
    When I run rake with honeybadger
    Then Honeybadger should send the rake command line as the component name
