source "https://rubygems.org"

gemspec

gem "allocation_stats", platforms: :mri, require: false
gem "appraisal", "~> 2.1"
gem "aruba", "~> 2.0"
gem "rspec", "~> 3.0"
gem "rspec-its", "~> 1.3.1"
gem "ruby-prof", platforms: :mri, require: false
gem "timecop"
gem "webmock"
gem "bigdecimal"
gem "base64"
gem "mutex_m"

# Required by feature specs.
gem "capistrano"
gem "rake"

# Nothing here requires rdoc directly, but it is a transitive dependency
# (aruba -> irb -> rdoc), and RDoc 8 depends on RBS 4, whose native
# extension does not build on JRuby. This pin constrains that resolution.
gem "rdoc", "<= 8.1.0"

gem "bump", "~> 0.10.0"

group :development do
  gem "guard"
  gem "guard-rspec"
  gem "pry"
  gem "pry-byebug", platforms: :mri
  gem "standard"
end
