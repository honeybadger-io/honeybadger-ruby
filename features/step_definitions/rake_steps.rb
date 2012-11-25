When /I run rake with (.+)/ do |command|
  @rake_command = "rake #{command.gsub(' ','_')}"
  @rake_result = `cd features/support/rake && #{@rake_command} 2>&1`
end

Then /Honeybadger should (|not) ?catch the exception/ do |condition|
  if condition=='not'
    @rake_result.should_not =~ /^honeybadger/
  else
    @rake_result.should =~ /^honeybadger/
  end
end

Then /Honeybadger should send the rake command line as the component name/ do
  component = @rake_result.match(/^honeybadger (.*)$/)[1]
  component.should == @rake_command
end
