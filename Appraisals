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
  gem 'sham_rack', require: false
end

appraise 'sinatra' do
  gem 'sinatra'
end

appraise 'delayed_job' do
  gem 'delayed_job', '< 4.1.2' # See https://github.com/collectiveidea/delayed_job/pull/931
end

appraise 'rails3.2' do
  gem 'rails', '~> 3.2.12'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
  gem 'capistrano', '~> 2.0'
end

appraise 'rails4.0' do
  gem 'rails', '~> 4.0.0'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
end

appraise 'rails4.1' do
  gem 'rails', '~> 4.1.4'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
end

appraise 'rails4.2' do
  gem 'rails', '~> 4.2.4'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
end

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2.2')
  # The latest officially supported Rails/Rack release
  appraise 'rails5.0' do
    gem 'rails', '~> 5.0.0'
    gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
    gem 'rack-mini-profiler', require: false
  end

  appraise 'rails' do
    gem 'rails', github: 'rails/rails'
    gem 'rack', github: 'rack/rack'
    gem 'arel', github: 'rails/arel'
    gem 'capistrano', '~> 3.0'
    gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]

    # Listen is a soft-dependency in Rails 5. Guard requires listen (which makes
    # it present when generating a new Rails app), so Rails expects it to be
    # there. See https://github.com/rails/rails/pull/24066
    gem 'listen'
  end

  appraise 'rack' do
    gem 'rack', '>= 2.0.0'
    gem 'sham_rack', require: false
  end
end
