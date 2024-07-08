require File.expand_path('../lib/honeybadger/version.rb', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'honeybadger'
  s.version     = Honeybadger::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Error reports you can be happy about.'
  s.description = 'Make managing application errors a more pleasant experience.'
  s.authors     = ['Honeybadger Industries LLC']
  s.email       = ['support@honeybadger.io']
  s.homepage    = 'https://www.honeybadger.io/for/ruby/'
  s.license     = 'MIT'
  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/honeybadger-io/honeybadger-ruby/issues',
    'changelog_uri'     => 'https://github.com/honeybadger-io/honeybadger-ruby/blob/master/CHANGELOG.md',
    'documentation_uri' => 'https://docs.honeybadger.io/lib/ruby/',
    'homepage_uri'      => 'https://www.honeybadger.io/for/ruby/',
    'source_code_uri'   => 'https://github.com/honeybadger-io/honeybadger-ruby'
  }

  s.required_ruby_version = '>= 2.3.0'

  s.rdoc_options << '--markup=tomdoc'
  s.rdoc_options << '--main=README.md'

  s.files  = Dir['lib/**/*.{rb,erb}']
  s.files += Dir['bin/*']
  # CI installs caches installed gems in vendor/bundle, but we don't want to include them in the gem.
  s.files += Dir['vendor/**/*.{rb,rake,cap}'].reject { |file| file.start_with?("vendor/bundle") }
  s.files += Dir['resources/**/*.crt']
  s.files += Dir['*.md']
  s.files += ['LICENSE']

  s.require_paths = ['lib', 'vendor/capistrano-honeybadger/lib']

  s.executables << 'honeybadger'
end
