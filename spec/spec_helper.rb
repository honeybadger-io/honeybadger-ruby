require "aruba/rspec"
require "aruba/api"
require "fileutils"
require "logger"
require "pathname"
require "rspec/its"
require "webmock/rspec"

# We don't want this bleeding through in tests. (i.e. from CircleCi)
ENV["RACK_ENV"] = nil
ENV["RAILS_ENV"] = nil

require "honeybadger/ruby"

begin
  require "i18n"
  I18n.enforce_available_locales = false
rescue LoadError
  nil
end

# We are unable to run ActiveRecord with rails edge on jruby as the sqlite
# adapter is not supported, so we are skipping ActiveRecord specs just for that
# runtime and Rails version.
SKIP_ACTIVE_RECORD = !!(defined?(JRUBY_VERSION) && defined?(Rails) && (Rails::VERSION::PRE == "alpha" || Rails::VERSION::MAJOR >= 8))

Dir[File.expand_path("../support/**/*.rb", __FILE__)].sort.each { |f| require f }

TMP_DIR = Pathname.new(File.expand_path("../../tmp", __FILE__))
FIXTURES_PATH = Pathname.new(File.expand_path("../fixtures/", __FILE__))
NULL_LOGGER = Logger.new(File::NULL)
NULL_LOGGER.level = Logger::Severity::DEBUG

def init_honeybadger_agent_instance!
  Honeybadger::Agent.instance = Honeybadger::Agent.new(Honeybadger::Config.new(api_key: "gem testing", backend: "null", logger: NULL_LOGGER))
end

# We call this once on load and once after each spec context runs to restore the
# global agent instance. This helps the unit tests run faster.
init_honeybadger_agent_instance!

# Clean up the aruba directory (similar to what Aruba does before each scenario)
FileUtils.rm_rf(TMP_DIR.join("aruba"))
FileUtils.mkdir_p(TMP_DIR.join("aruba"))

Aruba.configure do |config|
  # Create a unique directory to support parallel test runners
  config.working_directory = "tmp/aruba/test_#{Process.pid}_#{SecureRandom.hex(4)}"

  t = (RUBY_PLATFORM == "java") ? 120 : 12
  config.exit_timeout = t
  config.io_wait_timeout = t
end

RSpec.configure do |config|
  ##
  # Global RSpec config
  Kernel.srand config.seed

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  if /rails/.match?(ENV["BUNDLE_GEMFILE"])
    config.filter_run_excluding framework: ->(v) { !v || v != :rails }
  elsif /sinatra/.match?(ENV["BUNDLE_GEMFILE"])
    config.filter_run_excluding framework: ->(v) { !v || v != :sinatra }
  elsif /rake/.match?(ENV["BUNDLE_GEMFILE"])
    config.filter_run_excluding framework: ->(v) { !v || v != :rake }
  else
    config.filter_run_excluding framework: ->(v) { !v || v != :ruby }
  end

  config.include Helpers

  config.after(:each) do
    # Clear thread-local context
    Honeybadger.clear!

    # Clear test backend data
    Honeybadger::Backend::Test.notifications.clear
    Honeybadger::Backend::Test.events.clear
    Honeybadger::Backend::Test.check_ins.clear
  end

  config.after(:all) do
    init_honeybadger_agent_instance!
  end

  config.before(:each) do
    stub_request(:post, "https://api.honeybadger.io/v1/notices")
      .to_return(status: 200)
  end

  ##
  # Aruba config (for CLI tests)

  config.include ArubaHelpers, type: :aruba

  config.before(:all, type: :aruba) do
    require "honeybadger/cli"
  end

  config.before(:each, type: :aruba) do
    set_environment_variable("HONEYBADGER_BACKEND", "debug")
    set_environment_variable("HONEYBADGER_LOGGING_PATH", "STDOUT")
  end

  config.before(:each, type: :aruba, framework: :rails) do
    FileUtils.cp_r(FIXTURES_PATH.join("rails"), current_dir)
    cd("rails")
  end
end
