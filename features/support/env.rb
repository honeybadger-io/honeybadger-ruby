require 'rspec'
require 'aruba/cucumber'

# For Rails 4.2 default config/secret.yml in production.
ENV['SECRET_KEY_BASE'] = '7bc6db16868d67417ea7acade8c409c0b6a5d14bd578dcc8ef269a5a18d84e95dfcb12d6e5370a5655bc14db17be68f3900344aa87d7d97c01139e2fa6656bdc'

PROJECT_ROOT     = File.expand_path(File.join(File.dirname(__FILE__), '..', '..')).freeze
TEMP_DIR         = File.join(PROJECT_ROOT, 'tmp').freeze
LOCAL_RAILS_ROOT = File.join(TEMP_DIR, 'rails_root').freeze
RACK_FILE        = File.join(TEMP_DIR, 'rack_app.rb').freeze
RUBY_FILE        = File.join(TEMP_DIR, 'ruby_app.rb').freeze
SHIM_FILE        = File.join(PROJECT_ROOT, 'features', 'support', 'honeybadger_shim.rb.template')

Before do
  FileUtils.rm_rf(LOCAL_RAILS_ROOT)
end

Before do
  @dirs = ["tmp"]
  @aruba_timeout_seconds = 45
  @aruba_io_wait_seconds = 5
end
