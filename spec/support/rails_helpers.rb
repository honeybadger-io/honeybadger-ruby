module RailsHelpers
  def perform_request(uri, environment = 'production')
    request_script = <<-SCRIPT
        require File.expand_path('../config/environment', __FILE__)


        env      = Rack::MockRequest.env_for(#{uri.inspect})
        response = Testing::Application.call(env)


        response = response.last if response.last.is_a?(ActionDispatch::Response)
        response = response.last.to_a if defined?(Rack::BodyProxy) && response.last.is_a?(Rack::BodyProxy)

        if response.is_a?(Array)
          puts response.join
        else
          puts response.body
        end
    SCRIPT
    File.open(File.join(RAILS_ROOT, 'request.rb'), 'w') { |file| file.write(request_script) }
    assert_cmd("rails runner -e #{environment} request.rb")
  end

  def define_action(controller_and_action, definition, metal = false)
    controller_class_name, action = controller_and_action.split('#')
    controller_name = controller_class_name.split(/(?=[A-Z][a-z]*)/).join('_').downcase
    controller_file_name = RAILS_ROOT.join('app', 'controllers', "#{controller_name}.rb")
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

  def define_route(path, controller_action_pair)
    route = %(get "#{path}" => "#{controller_action_pair}")
    routes_file = File.join(RAILS_ROOT, "config", "routes.rb")
    File.open(routes_file, "r+") do |file|
      content = file.read
      content.gsub!(/^end$/, "  #{route}\nend")
      file.rewind
      file.write(content)
    end
  end

  def install_rails_shim
    # This must be loaded in application.rb because HB initialization happens
    # before config/initializers are run
    file_name = RAILS_ROOT.join('config', 'application.rb')
    File.open(file_name, 'a') do |file|
      file.write(<<-CONTENTS)
require 'sham_rack'

ShamRack.at('api.honeybadger.io', 443).stub.tap do |app|
  app.register_resource('/v1/ping', %({"features":{"notices":true,"feedback":true}, "limit":null}), 'application/json')
  app.register_resource('/v1/notices', %({"id":"123456789"}), 'application/json', 201)
  app.register_resource('/v1/metrics', '', "application/json", 201)
  app.register_resource('/v1/traces', '', 'application/json', 201)
end
      CONTENTS
    end
  end
end
