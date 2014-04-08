When /I run thor with (.+)/ do |command|
  FileUtils.cp(File.expand_path('../../support/test.thor', __FILE__), TEMP_DIR)
  step %(I run `thor #{command.gsub(' ','_')}`)
end
