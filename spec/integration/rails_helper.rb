begin
  # Require these early to work around https://github.com/jruby/jruby#6547
  #   can be pulled out > 9.2.14 of jruby.
  require "i18n"
  require "i18n/backend/simple"
  require "rails"

  require FIXTURES_PATH.join("rails", "config", "application.rb")
  require "honeybadger/init/rails"
  require "rspec/rails"

  RAILS_PRESENT = true

  # We are unable to run ActiveRecord with rails edge on jruby as the sqlite
  # adapter is not supported, so we are skipping ActiveRecord specs just for that
  # runtime and Rails version.
  SKIP_ACTIVE_RECORD = !!(defined?(JRUBY_VERSION) && (Rails::VERSION::PRE == "alpha" || Rails::VERSION::MAJOR >= 8))

  RSpec.configure do |config|
    config.before(:all) do
      RailsApp.initialize!
    end
  end
rescue LoadError
  RAILS_PRESENT = false
  SKIP_ACTIVE_RECORD = true
  puts "Skipping Rails integration specs."
end
