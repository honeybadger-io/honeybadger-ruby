begin
  # Require these early to work around https://github.com/jruby/jruby#6547
  #   can be pulled out > 9.2.14 of jruby.
  require "i18n"
  require "i18n/backend/simple"
  require "rails"
  RAILS_PRESENT = true

  # We are unable to run Activerecord with rails edge on jruby as the sqlite
  # adapter is not supported, so we are skipping activrecord specs just for
  # that runtime and Rails version
  SKIP_ACTIVE_RECORD = !!(defined?(JRUBY_VERSION) && (Rails::VERSION::PRE == "alpha" || Rails::VERSION::MAJOR >= 8))

  require FIXTURES_PATH.join("rails", "config", "application.rb")
  require "honeybadger/init/rails"
  require "rspec/rails"
rescue LoadError
  RAILS_PRESENT = false
  SKIP_ACTIVE_RECORD = true
  puts "Skipping Rails integration specs."
end

# Defining this as a method as we only want to include these hooks in rails
# integration specs. Since these specs run inline with non-rails specs, we
# don't want to attach these hooks to the global config
def load_rails_hooks(spec)
  spec.before(:all) do
    # Because we create a new Agent after each spec run, we need to make sure
    # that rerun the after_initialize hook to initilize our Agent
    if RailsApp.initialized?
      ActiveSupport.run_load_hooks(:before_initialize, RailsApp)
      ActiveSupport.run_load_hooks(:after_initialize, RailsApp)
    else
      RailsApp.initialize!
    end
  end

  spec.before(:each) do
    Honeybadger.configure do |config|
      config.api_key = "gem testing"
      config.backend = "test"
    end
  end

  spec.after(:each) do
    Honeybadger::Backend::Test.notifications[:notices].clear
  end
end
