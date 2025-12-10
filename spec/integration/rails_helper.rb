begin
  # Require these early to work around https://github.com/jruby/jruby#6547
  #   can be pulled out > 9.2.14 of jruby.
  require "i18n"
  require "i18n/backend/simple"
  require "rails"

  require FIXTURES_PATH.join("rails", "config", "application.rb")
  require "honeybadger/init/rails"
  require "rspec/rails"

  RSpec.configure do |config|
    config.before(:all) do
      RailsApp.initialize!
    end
  end

  RAILS_PRESENT = true
rescue LoadError
  RAILS_PRESENT = false
  puts "Skipping Rails integration specs."
end
