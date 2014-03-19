Given /^the following Ruby app:$/ do |definition|
  File.open(RUBY_FILE, 'w') do |file|
    file.puts "require 'rubygems'"
    file.write(IO.read(SHIM_FILE))
    file.write(definition)
  end
end

When /^I execute the file$/ do
  step %(I run `ruby #{RUBY_FILE}`)
end

