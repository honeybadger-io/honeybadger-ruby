require File.expand_path('../lib/honeybadger/version.rb', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'honeybadger'
  s.version     = Honeybadger::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Error reports you can be happy about.'
  s.description = 'Make managing application errors a more pleasant experience.'
  s.authors     = ['Honeybadger Industries LLC']
  s.email       = ['support@honeybadger.io']
  s.homepage    = 'https://github.com/honeybadger-io/honeybadger-ruby'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 2.3.0'

  s.rdoc_options << '--markup=tomdoc'
  s.rdoc_options << '--main=README.md'

  s.files  = Dir['lib/**/*.{rb,erb}']
  s.files += Dir['bin/*']
  s.files += Dir['vendor/**/*.{rb,rake,cap}']
  s.files += Dir['resources/**/*.crt']
  s.files += Dir['*.md']
  s.files += ['LICENSE']

  s.require_paths = ['lib', 'vendor/capistrano-honeybadger/lib']

  s.executables << 'honeybadger'
end
