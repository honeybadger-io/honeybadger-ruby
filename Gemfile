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
gem "rdoc" # Used in Rakefile, removed from default gems in Ruby 3.5.0

# Required by feature specs.
gem "capistrano"
gem "rake"

# mathn has moved to a rubygem in Ruby 2.5.0: https://github.com/ruby/mathn
platforms :ruby_25 do
  gem "mathn"
end

gem "bump", "~> 0.10.0"

group :development do
  gem "guard"
  gem "guard-rspec"
  gem "pry"
  gem "pry-byebug", platforms: :mri
  gem "standard"
end
