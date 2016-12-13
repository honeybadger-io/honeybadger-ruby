RUBY2_PLATFORMS = Bundler::Dependency::PLATFORM_MAP.keys.grep(/^mri_[^0-1]/)

source 'https://rubygems.org'

gemspec

gem 'appraisal'
gem 'rdoc'
gem 'rspec', '>= 3.0'
gem 'rspec-its'
gem 'timecop'
gem 'aruba', '~> 0.14'
gem 'webmock', '< 2.3.0' # Locked for 1.9.3
gem 'guard'
gem 'guard-rspec'
gem 'pry'
gem 'pry-byebug', platforms: RUBY2_PLATFORMS

gem 'ruby-prof', platforms: :mri, require: false
gem 'allocation_stats', platforms: RUBY2_PLATFORMS-[:mri_20], require: false

# Capistrano 3.5.0 requires Ruby 2.0+, so lock it until we drop Ruby 1.9.3.
gem 'capistrano', '>= 3.2.0', '< 3.5.0', require: false

# Need to lock these dependencies until we no longer support 1.9.3.
gem 'net-ssh', '< 3.0'
gem 'listen', '< 3.1'
gem 'mail', '< 2.6.4'
gem 'addressable', '~> 2.4.0'
