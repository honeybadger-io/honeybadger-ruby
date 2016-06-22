guard :rspec, cmd: 'bundle exec rspec --fail-fast --require unit/spec_helper', all_after_pass: false do
  watch(%r{^spec/unit/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/unit/#{m[1]}_spec.rb" }
  watch('spec/unit/spec_helper.rb')  { "spec" }
end
