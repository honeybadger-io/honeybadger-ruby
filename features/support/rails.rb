module RailsHelpers
  def application_controller_filename
    controller_filename = File.join(rails_root, 'app', 'controllers', "application_controller.rb")
  end

  def rails2?
    rails_version =~ /^2/
  end

  def rails3?
    rails_version =~ /^3/
  end

  def rails4?
    rails_version =~ /^4/
  end

  def rails_root
    LOCAL_RAILS_ROOT
  end

  def rails_uses_rack?
    rails4? || rails3? || rails_version =~ /^2\.3/
  end

  def capify?
    require 'capistrano/version'
    !(defined?(Capistrano::VERSION) && Gem::Version.new(Capistrano::VERSION) >= Gem::Version.new('3.0.0'))
  end

  def rails_version
    @rails_version ||= `bundle exec rails -v`[/\d.+/]
  end

  def rails_uses_bundler?
    rails4? || rails3?
  end

  def rails_manages_gems?
    rails_version =~ /^2\.[123]/
  end

  def rails_supports_initializers?
    rails4? || rails3? || rails_version =~ /^2\./
  end

  def rails_finds_generators_in_gems?
    rails4? || rails3? || rails_version =~ /^2\./
  end

  def environment_path
    File.join(rails_root, 'config', 'environment.rb')
  end

  def rakefile_path
    File.join(rails_root, 'Rakefile')
  end

  def rails_initializer_file
    File.join(rails_root, 'config', 'initializers', 'honeybadger.rb')
  end

  def rails_non_initializer_honeybadger_config_file
    File.join(rails_root, 'config', 'honeybadger.rb')
  end

  def config_gem(gem_name, version = nil)
    run     = "Rails::Initializer.run do |config|"
    insert  = "  config.gem '#{gem_name}'"
    insert += ", :version => '#{version}'" if version
    content = File.read(environment_path)
    content = "require 'thread'\n#{content}"
    if content.sub!(run, "#{run}\n#{insert}")
      File.open(environment_path, 'wb') { |file| file.write(content) }
    else
      raise "Couldn't find #{run.inspect} in #{environment_path}"
    end
  end

  def disable_activerecord
    run     = "Rails::Initializer.run do |config|"
    insert  = "  config.frameworks -= [ :active_record ]"
    content = File.read(environment_path)
    if content.sub!(run, "#{run}\n#{insert}")
      File.open(environment_path, 'wb') { |file| file.write(content) }
    else
      raise "Couldn't find #{run.inspect} in #{environment_path}"
    end
  end

  def perform_request(uri, environment = 'production')
    if rails4? || rails3?
      request_script = <<-SCRIPT
        require File.expand_path('../config/environment', __FILE__)


        env      = Rack::MockRequest.env_for(#{uri.inspect})
        response = RailsRoot::Application.call(env)


        response = response.last if response.last.is_a?(ActionDispatch::Response)
        response = response.last.to_a if defined?(Rack::BodyProxy) && response.last.is_a?(Rack::BodyProxy)

        if response.is_a?(Array)
          puts response.join
        else
          puts response.body
        end
      SCRIPT
      File.open(File.join(rails_root, 'request.rb'), 'w') { |file| file.write(request_script) }
      step %(I run `rails runner -e #{environment} request.rb`)
    elsif rails_uses_rack?
      request_script = <<-SCRIPT
        require File.expand_path('../config/environment', __FILE__)

        env = Rack::MockRequest.env_for(#{uri.inspect})
        app = Rack::Lint.new(ActionController::Dispatcher.new)

        status, headers, body = app.call(env)

        response = ""
        if body.respond_to?(:to_str)
          response << body
        else
          body.each { |part| response << part }
        end

        puts response
      SCRIPT
      File.open(File.join(rails_root, 'request.rb'), 'w') { |file| file.write(request_script) }
      step %(I run `ruby -rthread ./script/runner -e #{environment} request.rb`)
    else
      uri = URI.parse(uri)
      request_script = <<-SCRIPT
        require 'cgi'
        class CGIWrapper < CGI
          def initialize(*args)
            @env_table = {}
            @stdinput = $stdin
            super(*args)
          end
          attr_reader :env_table
        end
        $stdin = StringIO.new("")
        cgi = CGIWrapper.new
        cgi.env_table.update({
          'HTTPS'          => 'off',
          'REQUEST_METHOD' => "GET",
          'HTTP_HOST'      => #{[uri.host, uri.port].join(':').inspect},
          'SERVER_PORT'    => #{uri.port.inspect},
          'REQUEST_URI'    => #{uri.request_uri.inspect},
          'PATH_INFO'      => #{uri.path.inspect},
          'QUERY_STRING'   => #{uri.query.inspect}
        })
        require 'dispatcher' unless defined?(ActionController::Dispatcher)
        Dispatcher.dispatch(cgi)
      SCRIPT
      File.open(File.join(rails_root, 'request.rb'), 'w') { |file| file.write(request_script) }
      step %(I run `ruby -rthread ./script/runner -e #{environment} request.rb`)
    end
  end

  def monkeypatch_old_version
    monkeypatchin= <<-MONKEYPATCHIN

    MissingSourceFile::REGEXPS << [/^cannot load such file -- (.+)$/i, 1]

    MONKEYPATCHIN

    File.open(File.join(rails_root,"config","initializers", 'monkeypatchin.rb'), 'w') { |file| file.write(monkeypatchin) }
  end

  def config_gem_dependencies
    insert = <<-END
    if Gem::VERSION >= "1.3.6"
      module Rails
        class GemDependency
          def requirement
            r = super
            (r == Gem::Requirement.default) ? nil : r
          end
        end
      end
    end
    END
    run     = "Rails::Initializer.run do |config|"
    content = File.read(environment_path)
    if content.sub!(run, "#{insert}\n#{run}")
      File.open(environment_path, 'wb') { |file| file.write(content) }
    else
      raise "Couldn't find #{run.inspect} in #{environment_path}"
    end
  end

  def require_thread
    content = File.read(rakefile_path)
    content = "require 'thread'\n#{content}"
    File.open(rakefile_path, 'wb') { |file| file.write(content) }
  end
end

World(RailsHelpers)
