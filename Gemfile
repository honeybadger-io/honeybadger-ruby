RUBY2_PLATFORMS = Bundler::Dependency::PLATFORM_MAP.keys.grep(/^mri_[^0-1]/)

source 'https://rubygems.org'

gemspec

group :development do
  gem 'guard'
  gem 'guard-rspec'
end

gem 'appraisal'
gem 'rdoc'
gem 'rspec', '>= 3.0'
gem 'rspec-its'
gem 'timecop'
gem 'aruba', '~> 0.6.2'
gem 'simplecov'
gem 'webmock'
gem 'pry'
gem 'pry-byebug', platforms: RUBY2_PLATFORMS

gem 'ruby-prof', platforms: :mri, require: false
gem 'allocation_stats', platforms: RUBY2_PLATFORMS-[:mri_20], require: false

gem 'capistrano', '>= 3.2.0', require: false

gem 'codeclimate-test-reporter', require: false, group: :test

# net-ssh >= 3.0 requires Ruby >= 2.0. Need to lock this dependency until we no
# longer support 1.9.3.
gem 'net-ssh', '~> 2.9'
