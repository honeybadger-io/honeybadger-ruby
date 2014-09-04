appraise 'standalone' do
end

if RUBY_PLATFORM !~ /java/
  appraise 'binding_of_caller' do
    gem 'binding_of_caller'
  end
end

appraise 'rake' do
  gem 'rake'
end

appraise 'thor' do
  gem 'thor'
end

appraise 'rack' do
  gem 'rack'
end

appraise 'sinatra' do
  gem 'sinatra'
end

appraise 'delayed_job' do
  gem 'delayed_job'
end

appraise 'rails3.0' do
  gem 'rails', '~> 3.0.17'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', '~>0.1.31 ', require: false
  gem 'capistrano', '~> 2.0'
end

appraise 'rails3.1' do
  gem 'rails', '~> 3.1.12'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
  gem 'capistrano', '~> 2.0'
end

appraise 'rails3.2' do
  gem 'rails', '~> 3.2.12'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
  gem 'capistrano', '~> 2.0'
end

appraise 'rails4.0' do
  gem 'rails', '~> 4.0.0'
  gem 'capistrano', '~> 3.0'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
end

appraise 'rails4.1' do
  gem 'rails', '~> 4.1.4'
  gem 'capistrano', '~> 3.0'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
end

# The latest officially supported Rails release
appraise 'rails' do
  gem 'rails', '~> 4.2.0.beta1'
  gem 'capistrano', '~> 3.0'
  gem 'better_errors', require: false, platforms: [:ruby_20, :ruby_21]
  gem 'rack-mini-profiler', require: false
end
