guard :test do
  watch(%r{^lib/(.+)\.rb$}) { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^test/unit/.+_test\.rb$})
  watch('test/test_helper.rb')  { "test" }
end
