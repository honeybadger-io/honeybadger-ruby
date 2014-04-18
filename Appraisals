appraise 'standalone' do
  gem 'honeybadger', :path => '../'
end

if RUBY_VERSION > '1.9' && RUBY_PLATFORM !~ /java/
  appraise 'binding_of_caller' do
    gem 'binding_of_caller'
    gem 'honeybadger', :path => '../'
  end
end

appraise 'rake' do
  gem 'rake'
  gem 'honeybadger', :path => '../'
end

appraise 'thor' do
  gem 'thor'
  gem 'honeybadger', :path => '../'
end

appraise 'rack' do
  gem 'rack'
  gem 'honeybadger', :path => '../'
end

appraise 'sinatra' do
  gem 'sinatra'
  gem 'honeybadger', :path => '../'
end

if RUBY_VERSION > '1.9'

  appraise 'rails3.2' do
    gem 'rails', '~> 3.2.17'
    gem 'honeybadger', :path => '../'
    gem 'better_errors', :require => false
    gem 'rack-mini-profiler', :require => false
    gem 'capistrano', '~> 2.0'
  end

  if RUBY_VERSION > '1.9.2'
    # The latest officially supported Rails release
    appraise 'rails' do
      gem 'rails', '~> 4.0.4'
      gem 'honeybadger', :path => '../'
      gem 'capistrano', '~> 3.0'
      gem 'better_errors', :require => false
      gem 'rack-mini-profiler', :require => false
    end

    appraise 'rails4.1' do
      gem 'rails', '~> 4.1.0'
      gem 'honeybadger', :path => '../'
      gem 'capistrano', '~> 3.0'
      gem 'better_errors', :require => false
      gem 'rack-mini-profiler', :require => false
    end
  end
end
