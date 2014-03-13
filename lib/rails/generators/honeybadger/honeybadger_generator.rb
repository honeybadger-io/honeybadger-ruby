require 'rails/generators'

class HoneybadgerGenerator < Rails::Generators::Base
  class_option :api_key, :aliases => "-k", :type => :string, :desc => "Your Honeybadger API key"
  class_option :heroku, :type => :boolean, :desc => "Use the Heroku addon to provide your Honeybadger API key"
  class_option :app, :aliases => "-a", :type => :string, :desc => "Your Heroku app name (only required if deploying to >1 Heroku app)"

  def self.source_root
    @_honeybadger_source_root ||= File.expand_path("../../../../../generators/honeybadger/templates", __FILE__)
  end

  def install
    ensure_api_key_was_configured
    ensure_plugin_is_not_present
    append_capistrano_hook
    generate_initializer unless api_key_configured?
    determine_api_key if heroku?
    test_honeybadger
  end

  private

  def ensure_api_key_was_configured
    if !options[:api_key] && !options[:heroku] && !api_key_configured?
      puts "Must pass --api-key or --heroku or create config/initializers/honeybadger.rb"
      exit
    end
  end

  def ensure_plugin_is_not_present
    if plugin_is_present?
      puts "You must first remove the honeybadger plugin. Please run: script/plugin remove honeybadger"
      exit
    end
  end

  def append_capistrano_hook
    if File.exists?('config/deploy.rb') && File.exists?('Capfile')
      append_file('Capfile', <<-HOOK)

        require 'honeybadger/capistrano'
      HOOK
    end
  end

  def api_key_expression
    s = if options[:api_key]
          "'#{options[:api_key]}'"
        elsif options[:heroku]
          "ENV['HONEYBADGER_API_KEY']"
        end
  end

  def generate_initializer
    template 'initializer.rb', 'config/initializers/honeybadger.rb'
  end

  def determine_api_key
    puts "Attempting to determine your API Key from Heroku..."
    ENV['HONEYBADGER_API_KEY'] = heroku_api_key
    if ENV['HONEYBADGER_API_KEY'] =~ /\S/
      puts "... Done."
      puts "Heroku's Honeybadger API Key is '#{ENV['HONEYBADGER_API_KEY']}'"
    else
      puts "... Failed."
      puts "WARNING: We were unable to detect the Honeybadger API Key from your Heroku environment."
      puts "Your Heroku application environment may not be configured correctly."
      puts "Have you configured multiple Heroku apps? Try using the '--app [app name]' flag." unless options[:app]
      exit 1
    end
  end

  def heroku_var(var, app_name = nil)
    app = app_name ? "--app #{app_name}" : ''
    Bundler.with_clean_env { `heroku config:get #{var} #{app}` }
  end

  def heroku_api_key
    heroku_var("HONEYBADGER_API_KEY", options[:app]).split.find {|x| x =~ /\S/ }
  end

  def heroku?
    options[:heroku] ||
      system("grep HONEYBADGER_API_KEY config/initializers/honeybadger.rb") ||
      system("grep HONEYBADGER_API_KEY config/environment.rb")
  end

  def api_key_configured?
    File.exists?('config/initializers/honeybadger.rb')
  end

  def test_honeybadger
    puts run("rake honeybadger:test --trace")
  end

  def plugin_is_present?
    File.exists?('vendor/plugins/honeybadger')
  end
end
