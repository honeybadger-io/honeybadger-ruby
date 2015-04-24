RUBY2_PLATFORMS = Bundler::Dependency::PLATFORM_MAP.keys.grep(/^mri_[^0-1]/)

source 'https://rubygems.org'

gemspec

gem 'rdoc'
gem 'rspec', '>= 3.0'
gem 'rspec-its'
gem 'guard'
gem 'guard-rspec'
gem 'timecop'
gem 'appraisal'
gem 'aruba'
gem 'simplecov'
gem 'webmock'
gem 'pry'

gem 'ruby-prof', platforms: :mri, require: false

platforms *RUBY2_PLATFORMS do
  gem 'allocation_stats', require: false
  gem 'pry-byebug'
end

gem 'capistrano', '>= 3.2.0', require: false

gem 'codeclimate-test-reporter', require: false, group: :test
