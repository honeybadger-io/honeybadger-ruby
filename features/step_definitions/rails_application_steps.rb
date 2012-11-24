require 'uri'
require 'active_support/core_ext/string/inflections'

When /^I generate a new Rails application$/ do
  rails_create_command = 'rails'
  rails_create_command << (rails3? ? ' new' : '')

  step %(I successfully run `#{rails_create_command} rails_root -O`)
  step %(I cd to "rails_root")
end

When /^I configure the Honeybadger shim$/ do
  shim_file = File.join(PROJECT_ROOT, 'features', 'support', 'honeybadger_shim.rb.template')
  if rails_supports_initializers?
    target = File.join(rails_root, 'config', 'initializers', 'honeybadger_shim.rb')
    FileUtils.cp(shim_file, target)
  else
    File.open(environment_path, 'a') do |file|
      file.puts
      file.write IO.read(shim_file)
    end
  end
end

When /^I configure my application to require Honeybadger$/ do
  if rails3?
    # Do nothing - bundler's on it
  elsif rails_manages_gems?
    config_gem('honeybadger')
  else
    File.open(environment_path, 'a') do |file|
      file.puts
      file.puts("require 'honeybadger'")
      file.puts("require 'honeybadger/rails'")
    end

    unless rails_finds_generators_in_gems?
      FileUtils.cp_r(File.join(PROJECT_ROOT, 'generators'), File.join(rails_root, 'lib'))
    end
  end
end

When /^I configure Honeybadger with:$/ do |config|
  if rails_manages_gems?
    requires = ''
  else
    requires = "require 'honeybadger'"
  end

  initializer_code = <<-EOF
    #{requires}
    Honeybadger.configure do |config|
      #{config}
    end
  EOF

  if rails_supports_initializers?
    File.open(rails_initializer_file, 'w') { |file| file.write(initializer_code) }
  else
    File.open(environment_path, 'a') do |file|
      file.puts
      file.puts initializer_code
    end
  end
end

When /^I run the honeybadger generator with "([^\"]*)"$/ do |generator_args|
  if rails3?
    step %(I successfully run `./script/rails generate honeybadger #{generator_args}`)
  else
    step %(I successfully run `./script/generate honeybadger #{generator_args}`)
  end
end

Then /^I should receive a Honeybadger notification$/ do
  step %(the output should contain "** [Honeybadger] Response from Honeybadger:")
  step %(the output should contain "123456789")
end

Then /^I should receive two Honeybadger notifications$/ do
  all_output.scan(/\[Honeybadger\] Response from Honeybadger:/).size.should == 2
end

Then /^I should see the Rails version$/ do
  step %(the output should contain "[Rails: #{rails_version}]")
end

When /^I define a( metal)? response for "([^\"]*)":$/ do |metal, controller_and_action, definition|
  controller_class_name, action = controller_and_action.split('#')
  controller_name = controller_class_name.underscore
  controller_file_name = File.join(rails_root, 'app', 'controllers', "#{controller_name}.rb")
  File.open(controller_file_name, "w") do |file|
    file.puts "class #{controller_class_name} < #{ metal ? 'ActionController::Metal' : 'ApplicationController'}"
    file.puts "def consider_all_requests_local; false; end"
    file.puts "def local_request?; false; end"
    file.puts "def #{action}"
    file.puts definition
    file.puts "end"
    file.puts "end"
  end
end

When /^I perform a request to "([^\"]*)"$/ do |uri|
  perform_request(uri)
end

When /^I route "([^\"]*)" to "([^\"]*)"$/ do |path, controller_action_pair|
  route = if rails3?
            %(match "#{path}", :to => "#{controller_action_pair}")
          else
            controller, action = controller_action_pair.split('#')
            %(map.connect "#{path}", :controller => "#{controller}", :action => "#{action}")
          end
  routes_file = File.join(rails_root, "config", "routes.rb")
  File.open(routes_file, "r+") do |file|
    content = file.read
    content.gsub!(/^end$/, "  #{route}\nend")
    file.rewind
    file.write(content)
  end
end

When /^I configure the Heroku gem shim with "([^\"]*)"( and multiple app support)?$/ do |api_key, multi_app|
  heroku_script_bin = File.join(TEMP_DIR, "bin")
  FileUtils.mkdir_p(heroku_script_bin)
  heroku_script     = File.join(heroku_script_bin, "heroku")
  heroku_env_vars = <<-VARS
HONEYBADGER_API_KEY    => myapikey
APP_NAME            => cold-moon-2929
BUNDLE_WITHOUT      => development:test
COMMIT_HASH         => lj32j42ss9332jfa2
DATABASE_URL        => postgres://fchovwjcyb:QLPVWmBBbf4hCG_YMrtV@ec3-107-28-193-23.compute-1.amazonaws.com/fhcvojwwcyb
LANG                => en_US.UTF-8
LAST_GIT_BY         => kensa
RACK_ENV            => production
SHARED_DATABASE_URL => postgres://fchovwjcyb:QLPVwMbbbF8Hcg_yMrtV@ec2-94-29-181-224.compute-1.amazonaws.com/fhcvojcwwyb
STACK               => bamboo-mri-1.9.2
URL                 => cold-moon-2929.heroku.com
  VARS
  single_app_script = <<-SINGLE
#!/bin/bash
if [ $1 == 'config' ]
then
  echo "#{heroku_env_vars}"
fi
  SINGLE

  multi_app_script = <<-MULTI
#!/bin/bash
if [[ $1 == 'config' && $2 == '--app' ]]
then
  echo "#{heroku_env_vars}"
fi
  MULTI

  File.open(heroku_script, "w") do |f|
    if multi_app
      f.puts multi_app_script
    else
      f.puts single_app_script
    end
  end
  FileUtils.chmod(0755, heroku_script)

  ENV['PATH'] = "#{heroku_script_bin}#{File::PATH_SEPARATOR}#{ENV['PATH']}"
end

Then /^my Honeybadger configuration should contain the following line:$/ do |line|
  configuration_file = if rails_supports_initializers?
    rails_initializer_file
  else
    rails_non_initializer_honeybadger_config_file
  end

  configuration = File.read(configuration_file)
  if ! configuration.include?(line.strip)
    raise "Expected text:\n#{configuration}\nTo include:\n#{line}\nBut it didn't."
  end
end

When /^I configure the application to filter parameter "([^\"]*)"$/ do |parameter|
  if rails3?
    application_filename = File.join(rails_root, 'config', 'application.rb')
    application_lines = File.open(application_filename).readlines

    application_definition_line       = application_lines.detect { |line| line =~ /Application/ }
    application_definition_line_index = application_lines.index(application_definition_line)

    application_lines.insert(application_definition_line_index + 1,
                             "    config.filter_parameters += [#{parameter.inspect}]")

   File.open(application_filename, "w") do |file|
     file.puts application_lines.join("\n")
   end
  else
   controller_filename = application_controller_filename
   controller_lines = File.open(controller_filename).readlines

   controller_definition_line       = controller_lines.detect { |line| line =~ /ApplicationController/ }
   controller_definition_line_index = controller_lines.index(controller_definition_line)

   controller_lines.insert(controller_definition_line_index + 1,
                           "    filter_parameter_logging #{parameter.inspect}")

   File.open(controller_filename, "w") do |file|
     file.puts controller_lines.join("\n")
   end
  end
end

When /^I install the "([^\"]*)" plugin$/ do |plugin_name|
  FileUtils.mkdir_p("#{rails_root}/vendor/plugins/#{plugin_name}")
end

When /^I unpack the "([^\"]*)" gem$/ do |gem_name|
  if rails3?
    step %(I successfully run `bundle pack`)
  elsif rails_manages_gems?
    step %(I successfully run `rake gems:unpack GEM=#{gem_name}`)
  else
    vendor_dir = File.join(rails_root, 'vendor', 'gems')
    FileUtils.mkdir_p(vendor_dir)
    step %(I successfully run `gem unpack #{gem_name}`)
    gem_path =
      Dir.glob(File.join(rails_root, 'vendor', 'gems', "#{gem_name}-*", 'lib')).first
    File.open(environment_path, 'a') do |file|
      file.puts
      file.puts("$: << #{gem_path.inspect}")
    end
  end
end

When /^I uninstall the "([^\"]*)" gem$/ do |gem_name|
  step %(I successfully run `gem uninstall #{gem_name}`)
end

When /^I install cached gems$/ do
  if rails3?
    step %(I successfully run `bundle install`)
  end
end

When /^I configure the notifier to use "([^\"]*)" as an API key$/ do |api_key|
  steps %{
    When I configure Honeybadger with:
      """
      config.api_key = #{api_key.inspect}
      """
  }
end
