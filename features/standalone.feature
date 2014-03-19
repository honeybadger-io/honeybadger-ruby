Feature: Use the notifier in a plain Ruby app
  Scenario: Rescue and exception in a Rack app
    Given the following Ruby app:
      """
      require 'honeybadger'

      Honeybadger.configure do |config|
        config.api_key = 'my_api_key'
        config.logger = Logger.new STDOUT
      end

      begin
        fail 'oops!'
      rescue => e
        Honeybadger.notify(e)
      end
      """
    When I execute the file
    Then I should receive a Honeybadger notification

  Scenario: Dependency injection
    Given the following Ruby app:
      """
      require 'honeybadger/dependency'

      Honeybadger::Dependency.register do
        injection { puts 'injected' }
      end

      require 'honeybadger'

      Honeybadger.configure do |config|
        config.api_key = 'my_api_key'
        config.logger = Logger.new STDOUT
      end

      begin
        fail 'oops!'
      rescue => e
        Honeybadger.notify(e)
      end
      """
    When I execute the file
    Then the output should contain "injected"
    And I should receive a Honeybadger notification

  # TODO: also test 'Then the output should contain "injection failure"' after default
  # logging is added.
  Scenario: Dependency injection exception
    Given the following Ruby app:
      """
      require 'honeybadger/dependency'

      Honeybadger::Dependency.register do
        injection { fail 'injection failure' }
      end

      require 'honeybadger'

      Honeybadger.configure do |config|
        config.api_key = 'my_api_key'
        config.logger = Logger.new STDOUT
      end

      begin
        fail 'oops!'
      rescue => e
        Honeybadger.notify(e)
      end
      """
    When I execute the file
    Then the output should not contain "injected"
    And I should receive a Honeybadger notification
