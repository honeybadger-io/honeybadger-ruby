# minimal rails gems required to run rails
# https://github.com/rails/rails/blob/main/rails.gemspec
RAILS_GEMS = %w[activesupport activemodel activerecord activejob railties actionpack]

appraise 'standalone' do
end

if RUBY_PLATFORM !~ /java/
  appraise 'binding_of_caller' do
    gem 'binding_of_caller'
  end
end

appraise 'rack-1' do
  # Old (pre-2.0) Rack, works on all Rubies.
  gem 'rack', '< 2.0'
end

appraise 'sinatra-1' do
  gem 'sinatra', '< 2.0'
  gem 'rack-test'
end

appraise 'delayed_job' do
  gem 'delayed_job', '< 4.1.2' # See https://github.com/collectiveidea/delayed_job/pull/931
end

appraise 'resque' do
  gem 'resque'
  gem 'mock_redis'
end

appraise 'rails5.2' do
  RAILS_GEMS.each { |rails_gem| gem rails_gem, "~> 5.2" }
  gem 'sqlite3', '~> 1.4', platforms: :mri
  gem 'activerecord-jdbcsqlite3-adapter', '~> 52', platforms: :jruby
  gem 'better_errors', require: false, platforms: :mri
  gem 'rack-mini-profiler', require: false
  gem 'rspec-rails'
end

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5.0')
  appraise 'rails6.0' do
    RAILS_GEMS.each { |rails_gem| gem rails_gem, "~> 6.0" }
    gem 'sqlite3', '~> 1.4', platforms: :mri
    gem 'activerecord-jdbcsqlite3-adapter', '~> 60', platforms: :jruby
    gem 'better_errors', require: false, platforms: :mri
    gem 'rack-mini-profiler', require: false
    gem 'rspec-rails'
  end

  appraise 'rails6.1' do
    RAILS_GEMS.each { |rails_gem| gem rails_gem, "~> 6.1" }
    gem 'sqlite3', '~> 1.4', platforms: :mri
    gem 'activerecord-jdbcsqlite3-adapter', '~> 61', platforms: :jruby
    gem 'better_errors', require: false, platforms: :mri
    gem 'rack-mini-profiler', require: false
    gem 'rspec-rails'
    gem 'listen'
  end

  appraise 'rails7.0' do
    RAILS_GEMS.each { |rails_gem| gem rails_gem, "~> 7.0" }
    gem 'sqlite3', '~> 1.4', platforms: :mri
    gem 'activerecord-jdbcsqlite3-adapter', '~> 60', platforms: :jruby
    gem 'better_errors', require: false, platforms: :mri
    gem 'rack-mini-profiler', require: false
    gem 'rspec-rails'
  end

  # Rails edge
  appraise 'rails' do
    RAILS_GEMS.each { |rails_gem| gem rails_gem, github: 'rails' }
    gem 'rack', github: 'rack/rack'
    gem 'arel', github: 'rails/arel'
    gem 'sqlite3', '~> 1.4', platforms: :mri
    gem 'capistrano', '~> 3.0'
    gem 'better_errors', require: false, platforms: :mri
    gem 'rspec-rails'

    # Listen is a soft-dependency in Rails 5. Guard requires listen (which makes
    # it present when generating a new Rails app), so Rails expects it to be
    # there. See https://github.com/rails/rails/pull/24066
    gem 'listen'
  end
end

appraise 'rack' do
  gem 'rack', '>= 2.0.0'
end

appraise 'sinatra' do
  gem 'sinatra', '~> 2.0.0.beta1'
  gem 'rack-test'
end
