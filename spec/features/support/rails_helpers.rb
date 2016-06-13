module RailsHelpers
  def perform_request(uri, environment = 'production')
    request_script = <<-SCRIPT
        require File.expand_path('../config/environment', __FILE__)


        env      = Rack::MockRequest.env_for(#{uri.inspect})
        response = RailsApp::Application.call(env)


        response = response.last if response.last.is_a?(ActionDispatch::Response)
        response = response.last.to_a if defined?(Rack::BodyProxy) && response.last.is_a?(Rack::BodyProxy)

        if response.is_a?(Array)
          puts response.join
        else
          puts response.body
        end
    SCRIPT
    File.open(File.join(RAILS_ROOT, 'request.rb'), 'w') { |file| file.write(request_script) }
    run_simple("rails runner -e #{environment} request.rb", fail_on_error: true)
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
end
