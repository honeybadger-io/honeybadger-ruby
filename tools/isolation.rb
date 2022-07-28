require 'bundler'

catch :failure do
  Dir['spec/unit/**/*_spec.rb'].each do |s|
    Bundler.with_unbundled_env { puts `bundle exec rspec --pattern #{s}` }
    throw :failure unless $?.exitstatus == 0
  end
end
