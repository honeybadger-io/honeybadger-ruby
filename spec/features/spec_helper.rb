require 'aruba/rspec'
require 'logger'
require 'pathname'
require 'pry'

TMP_DIR = Pathname.new(File.expand_path('../../../tmp', __FILE__))
FIXTURES_PATH = Pathname.new(File.expand_path('../fixtures/', __FILE__))
CMD_ROOT = TMP_DIR.join('features')
RAILS_CACHE = TMP_DIR.join('rails_app')
RAILS_ROOT = CMD_ROOT.join('current')

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each {|f| require f}

Aruba.configure do |config|
  t = RUBY_PLATFORM == 'java' ? 120 : 12
  config.working_directory = 'tmp/features'
  config.exit_timeout = t
  config.io_wait_timeout = t
end

RSpec.configure do |config|
  Kernel.srand config.seed

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.alias_example_group_to :feature, type: :feature, framework: :ruby
  config.alias_example_group_to :scenario

  config.include Aruba::Api
  config.include CommandLine

  config.before(:each) do
    set_environment_variable('HONEYBADGER_BACKEND', 'debug')
    set_environment_variable('HONEYBADGER_LOGGING_PATH', 'STDOUT')

    # We don't want this bleeding through in tests. (i.e. from CircleCi)
    set_environment_variable('RACK_ENV', '')

    # Minimum configuration required by Rails 4.1+ in production.
    set_environment_variable('RAILS_ENV', 'production')
    set_environment_variable('SECRET_KEY_BASE', '92f07c3efdd726e459c3ff7e07a8e82b079633adb4fffb8ee419ba367d76fade867203a53b127079329b519bd9dda46f67c57105562422832b50fa47fa8504b0')
  end

  config.before(:all, framework: :rails) do
    FileUtils.rm_r(RAILS_CACHE) if RAILS_CACHE.exist?
  end

  config.before(:each, framework: :rails) do
    unless RAILS_CACHE.exist?
      # This command needs to run in the before(:each) callback to satisfy
      # aruba, but we only want to run it once per suite.
      run_simple("rails new #{ RAILS_CACHE } -O -S -G -J -T --skip-gemfile --skip-bundle", fail_on_error: true)
    end

    # Copying the cached version is faster than generating a new rails app
    # before each scenario.
    FileUtils.cp_r(RAILS_CACHE, RAILS_ROOT)
    cd('current')
  end

  if ENV['BUNDLE_GEMFILE'] =~ /rails/
    config.filter_run_excluding framework: ->(v) { v != :rails }
  elsif ENV['BUNDLE_GEMFILE'] =~ /sinatra/
    config.filter_run_excluding framework: ->(v) { v != :sinatra }
  elsif ENV['BUNDLE_GEMFILE'] =~ /rake/
    config.filter_run_excluding framework: ->(v) { v != :rake }
  else
    config.filter_run_excluding framework: ->(v) { v != :ruby }
  end
end
