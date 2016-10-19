require 'aruba/rspec'
require 'logger'
require 'pathname'
require 'pry'

TMP_DIR = Pathname.new(File.expand_path('../../../tmp', __FILE__))
FIXTURES_PATH = Pathname.new(File.expand_path('../fixtures/', __FILE__))
CMD_ROOT = TMP_DIR.join('features')

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

  config.alias_example_group_to :feature, type: :feature
  config.alias_example_group_to :scenario

  config.include Aruba::Api
  config.include CommandLine

  config.before(:each) do
    set_environment_variable('HONEYBADGER_BACKEND', 'debug')
    set_environment_variable('HONEYBADGER_LOGGING_PATH', 'STDOUT')

    # We don't want this bleeding through in tests. (i.e. from CircleCi)
    set_environment_variable('RACK_ENV', '')
  end
end
