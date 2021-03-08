# require 'aruba/rspec'
require 'fileutils'
require 'logger'
require 'pathname'
require 'rspec/its'
require 'webmock/rspec'

# We don't want this bleeding through in tests. (i.e. from CircleCi)
ENV['RACK_ENV'] = nil
ENV['RAILS_ENV'] = nil

require 'honeybadger/ruby'

begin
  require 'i18n'
  I18n.enforce_available_locales = false
rescue LoadError
  nil
end

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each {|f| require f}

TMP_DIR = Pathname.new(File.expand_path('../../tmp', __FILE__))
FIXTURES_PATH = Pathname.new(File.expand_path('../fixtures/', __FILE__))
NULL_LOGGER = Logger.new(File::NULL)
NULL_LOGGER.level = Logger::Severity::DEBUG

RSpec.configure do |config|
  Kernel.srand config.seed

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.alias_example_group_to :feature, type: :feature
  config.alias_example_group_to :scenario

  # config.include Aruba::Api, type: :feature
  config.include FeatureHelpers, type: :feature

  def set_environment_variable(var, value)
    ENV[var.to_s] = value.to_s
  end

  config.before(:all, type: :feature) do
    feature_dir = File.join("tmp/features")
    FileUtils.mkdir_p(feature_dir)
    Dir.chdir(feature_dir)
  end

  config.before(:each, type: :feature) do
    require "honeybadger/cli"
    set_environment_variable('HONEYBADGER_BACKEND', 'debug')
    set_environment_variable('HONEYBADGER_LOGGING_PATH', 'STDOUT')
  end

  config.include Helpers

  config.before(:all) do
    Honeybadger::Agent.instance = Honeybadger::Agent.new(Honeybadger::Config.new(backend: 'null', logger: NULL_LOGGER))
  end

  config.after(:each) do
    Honeybadger.clear!
  end

  begin
    # Rack is a soft dependency, and so we want to be able to run the test suite
    # without it.
    require 'rack'
  rescue LoadError
    puts 'Excluding specs which depend on Rack.'
    config.exclude_pattern = 'spec/unit/honeybadger/rack/*_spec.rb'
  end

  config.before(:each, framework: :rails) do
    FileUtils.cp_r(FIXTURES_PATH.join('rails'), current_dir)
    cd('rails')
  end

  if ENV['BUNDLE_GEMFILE'] =~ /rails/
    config.filter_run_excluding framework: ->(v) { !v || v != :rails }
  elsif ENV['BUNDLE_GEMFILE'] =~ /sinatra/
    config.filter_run_excluding framework: ->(v) { !v || v != :sinatra }
  elsif ENV['BUNDLE_GEMFILE'] =~ /rake/
    config.filter_run_excluding framework: ->(v) { !v || v != :rake }
  else
    config.filter_run_excluding framework: ->(v) { !v || v != :ruby }
  end
end
