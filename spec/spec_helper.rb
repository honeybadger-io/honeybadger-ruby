require 'rspec'
require 'honeybadger'

begin
  require 'binding_of_caller'
rescue LoadError
  nil
end

# Require files in spec/support/ and its subdirectories.
Dir[File.expand_path('../../spec/support/**/*.rb', __FILE__)].each {|f| require f}

RSpec.configure do |c|
  c.mock_with :rspec
  c.color_enabled = true
  c.tty = true

  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true

  c.include Helpers
  c.after(:each) { Honeybadger.context.clear! }
end
