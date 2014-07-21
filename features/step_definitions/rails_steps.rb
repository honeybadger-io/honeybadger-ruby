require 'uri'

When /^I generate a new Rails application$/ do
  rails_create_command = rails2? ? 'rails rails_root' :
    'rails new rails_root -O -S -G -J -T --skip-gemfile --skip-bundle'

  step %(I successfully run `bundle exec #{rails_create_command}`)
  step %(I cd to "rails_root")

  require_thread

  monkeypatch_old_version if rails_version == "2.3.14"

  if rails2?
    config_gem_dependencies
    disable_activerecord
  end
end

When /^I configure the Honeybadger (failure )?shim$/ do |failure|
  shim_file = File.join(PROJECT_ROOT, 'features', 'support', "honeybadger#{failure ? '_failure' : nil}_shim.rb.template")
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
  if rails_uses_bundler?
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
  requires = if rails_uses_bundler? || rails_manages_gems?
    ''
  else
    %(require 'honeybadger')
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
  if rails2?
    step %(I successfully run `./script/generate honeybadger #{generator_args}`)
  else
    step %(I successfully run `rails generate honeybadger #{generator_args}`)
  end
end

Then /^I should receive (.+) Honeybadger notifications?$/ do |number|
  number = case number
           when /^(one|a)$/ then 1
           when 'two' then 2
           else number end

  all_output.scan(/\[Honeybadger\] Success: Net::HTTPOK/).size.should == number
  step %(the output should contain "123456789")
end

Then /^the request\s?(url|component|action|params|session|cgi_data|context)? should( not)? contain "([^\"]*)"$/ do |key, negate, expected|
  notice = all_output.match(/Notice: (\{.+\})/) ? JSON.parse(Regexp.last_match(1)) : {}
  hash = key ? notice['request'][key.strip] : notice['request']
  hash.to_s.send(negate ? :should_not : :should, match(/#{Regexp.escape(expected)}/))
end

Then /^I should see the Rails version$/ do
  step %(the output should contain "[Rails: #{rails_version}]")
end

When /^I define a( metal)? response for "([^\"]*)":$/ do |metal, controller_and_action, definition|
  controller_class_name, action = controller_and_action.split('#')
  controller_name = controller_class_name.split(/(?=[A-Z][a-z]*)/).join('_').downcase
  controller_file_name = File.join(rails_root, 'app', 'controllers', "#{controller_name}.rb")
  File.open(controller_file_name, "w") do |file|
    file.puts "class #{controller_class_name} < #{ (metal && !rails2?) ? 'ActionController::Metal' : 'ApplicationController'}"
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

When /^I configure the user informer/ do
  error_page = File.join(rails_root, 'public', '500.html')
  File.open(error_page, "r+") do |file|
    content = file.read
    content.gsub!('</body>', '<!-- HONEYBADGER ERROR --></body>')
    file.rewind
    file.write(content)
  end
end

When /^I configure the user feedback form/ do
  error_page = File.join(rails_root, 'public', '500.html')
  File.open(error_page, "r+") do |file|
    content = file.read
    content.gsub!('</body>', '<!-- HONEYBADGER FEEDBACK --></body>')
    file.rewind
    file.write(content)
  end
end

When /^I route "([^\"]*)" to "([^\"]*)"$/ do |path, controller_action_pair|
  route = if rails2?
            controller, action = controller_action_pair.split('#')
            %(map.connect "#{path}", :controller => "#{controller}", :action => "#{action}")
          else
            %(get "#{path}" => "#{controller_action_pair}")
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
  single_app_script = <<-SINGLE
#!/bin/bash
if [[ $1 == 'config:get' && $2 == 'HONEYBADGER_API_KEY' ]]
then
  echo "#{api_key}"
fi
  SINGLE

  multi_app_script = <<-MULTI
#!/bin/bash
if [[ $1 == 'config:get' && $2 == 'HONEYBADGER_API_KEY' && $3 == '--app' ]]
then
  echo "#{api_key}"
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
  if rails2?
   controller_filename = application_controller_filename
   controller_lines = File.open(controller_filename).readlines

   controller_definition_line       = controller_lines.detect { |line| line =~ /ApplicationController/ }
   controller_definition_line_index = controller_lines.index(controller_definition_line)

   controller_lines.insert(controller_definition_line_index + 1,
                           "    filter_parameter_logging #{parameter.inspect}")

   File.open(controller_filename, "w") do |file|
     file.puts controller_lines.join("\n")
   end
  else
    application_filename = File.join(rails_root, 'config', 'application.rb')
    application_lines = File.open(application_filename).readlines

    application_definition_line       = application_lines.detect { |line| line =~ /Application/ }
    application_definition_line_index = application_lines.index(application_definition_line)

    application_lines.insert(application_definition_line_index + 1,
                             "    config.filter_parameters += [#{parameter.inspect}]")

   File.open(application_filename, "w") do |file|
     file.puts application_lines.join("\n")
   end
  end
end

When /^I install the "([^\"]*)" plugin$/ do |plugin_name|
  FileUtils.mkdir_p("#{rails_root}/vendor/plugins/#{plugin_name}")
end

When /^I configure the notifier to use "([^\"]*)" as an API key$/ do |api_key|
  steps %{
    When I configure Honeybadger with:
      """
      config.api_key = #{api_key.inspect}
      """
  }
end

When /^I configure Rails with:$/ do |config|
  if rails2?
    fail 'This step definition requires Rails 3+. Please add support for Rails 2 if you need it.'
  else
    application_filename = File.join(rails_root, 'config', 'application.rb')
    application_lines = File.open(application_filename).readlines

    application_definition_line       = application_lines.detect { |line| line =~ /Application/ }
    application_definition_line_index = application_lines.index(application_definition_line)

    application_lines.insert(application_definition_line_index + 1, config)

    File.open(application_filename, "w") do |file|
      file.puts application_lines.join("\n")
    end
  end
end

When /^I install capistrano$/ do
  if capify?
    step %(I successfully run `capify .`)
  else
    step %(I successfully run `cap install`)
  end
end
