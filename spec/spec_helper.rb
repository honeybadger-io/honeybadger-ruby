require 'rspec/its'
require 'pathname'
require 'logger'
require 'simplecov'

TMP_DIR = Pathname.new(File.expand_path('../../tmp', __FILE__))
FIXTURES_PATH = Pathname.new(File.expand_path('../fixtures/', __FILE__))
NULL_LOGGER = Logger.new('/dev/null')
NULL_LOGGER.level = Logger::Severity::DEBUG

begin
  require 'binding_of_caller'
rescue LoadError
  nil
end

begin
  require 'i18n'
  I18n.enforce_available_locales = false
rescue LoadError
  nil
end

# Require files in spec/support/ and its subdirectories.
Dir[File.expand_path('../../spec/support/**/*.rb', __FILE__)].each {|f| require f}

# The `.rspec` file also contains a few flags that are not defaults but that
# users commonly want.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  config.expect_with :rspec do |expectations|
    # Enable only the newer, non-monkey-patching expect syntax.
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    # Enable only the newer, non-monkey-patching expect syntax.
    mocks.syntax = :expect

    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended.
    mocks.verify_partial_doubles = true
  end

  config.include Helpers

  config.before(:each) do
    defined?(Honeybadger.config) and
      Honeybadger.config = Honeybadger::Config::Default.new(backend: 'test'.freeze)

    defined?(Honeybadger::Config) and
      ENV.each_pair do |k,v|
      next unless k.match(Honeybadger::Config::Env::CONFIG_KEY)
      ENV.delete(k)
    end
  end

  config.after(:each) do
    defined?(Honeybadger.worker) && Honeybadger.worker and
      Honeybadger.worker.stop

    Thread.current[:__honeybadger_context] = nil
  end

  # Feature specs
  config.alias_example_group_to :feature, type: :feature, framework: :ruby
  config.alias_example_group_to :scenario

  config.include CommandLine, type: :feature
  config.include RailsHelpers, type: :feature, framework: :rails

  config.before(:all, type: :feature) do
    self.dirs = ['tmp', 'features']
    t = RUBY_PLATFORM == 'java' ? 120 : 5
    self.aruba_timeout_seconds = t
    self.aruba_io_wait_seconds = t
    clean_current_dir
  end

  config.before(:each, type: :feature) do
    terminate_processes!
    self.processes = []
    self.dirs = ['tmp', 'features']
    restore_env
    set_env('HONEYBADGER_BACKEND', 'debug')
    set_env('HONEYBADGER_LOGGING_PATH', 'STDOUT')
  end

  config.before(:each, type: :feature, framework: :ruby) do
    clean_current_dir
  end

  config.before(:all, type: :feature, framework: :rails) do
    cmd('rails new testing -O -S -G -J -T --skip-gemfile --skip-bundle')
  end

  config.before(:each, type: :feature, framework: :rails) do
    FileUtils.rm_r(RAILS_ROOT) if RAILS_ROOT.exist?
    FileUtils.cp_r(CMD_ROOT.join('testing'), RAILS_ROOT)
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


if ENV['TRAVIS']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
elsif !ENV['GUARD']
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
  end
end
