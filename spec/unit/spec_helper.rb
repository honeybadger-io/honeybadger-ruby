require 'logger'
require 'pathname'
require 'pry'
require 'rspec/its'

# We don't want this bleeding through in tests. (i.e. from CircleCi)
ENV['RACK_ENV'] = nil
ENV['RAILS_ENV'] = nil

TMP_DIR = Pathname.new(File.expand_path('../../../tmp', __FILE__))
FIXTURES_PATH = Pathname.new(File.expand_path('../fixtures/', __FILE__))
NULL_LOGGER = Logger.new('/dev/null')
NULL_LOGGER.level = Logger::Severity::DEBUG

# Soft dependencies
%w(rack binding_of_caller).each do |lib|
  begin
    require lib
  rescue LoadError
    puts "Excluding specs for #{ lib }"
  end
end

begin
  require 'i18n'
  I18n.enforce_available_locales = false
rescue LoadError
  nil
end

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each {|f| require f}

RSpec.configure do |config|
  Kernel.srand config.seed

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.include Helpers

  config.before(:each) do
    Honeybadger::Agent.instance = Honeybadger::Agent.new(Honeybadger::Config.new(backend: :null, logger: NULL_LOGGER))

    defined?(Honeybadger::Config::Env) and
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

  begin
    require 'sham_rack'
  rescue LoadError
    puts 'Excluding Rack specs: sham_rack is not available.'
    config.exclude_pattern = 'spec/unit/honeybadger/rack/*_spec.rb'
  end
end
