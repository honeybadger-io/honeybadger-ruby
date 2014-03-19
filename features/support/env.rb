require 'rspec'
require 'aruba/cucumber'

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
