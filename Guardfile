guard :rspec, cmd: "bundle exec rspec --fail-fast", all_after_pass: false do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/unit/#{m[1]}_spec.rb" }
  watch("spec/spec_helper.rb") { "spec" }
end
