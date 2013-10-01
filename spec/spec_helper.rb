require 'rspec'
require 'honeybadger'

# Require files in spec/support/ and its subdirectories.
Dir[File.expand_path('../../spec/support/**/*.rb', __FILE__)].each {|f| require f}

RSpec.configure do |c|
  c.mock_with :rspec
  c.color_enabled = true
  c.tty = true

  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run :focus => true
  c.filter_run_excluding :rails2 => !(ENV['BUNDLE_GEMFILE'] =~ /rails2/)
  c.run_all_when_everything_filtered = true

  include Helpers
  c.after(:each) { Honeybadger.context.clear! }
end
