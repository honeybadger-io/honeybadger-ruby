namespace :honeybadger do
  desc "Notify Honeybadger of a new deploy."
  task :deploy do
    require 'honeybadger_tasks'

    if defined?(Rails.root)
      initializer_file = Rails.root.join('config', 'initializers','honeybadger.rb')

      if initializer_file.exist?
        load initializer_file
      else
        Rake::Task[:environment].invoke
      end
    end

    HoneybadgerTasks.deploy(:environment    => ENV['TO'],
                            :revision       => ENV['REVISION'],
                            :repository     => ENV['REPO'],
                            :local_username => ENV['USER'],
                            :api_key        => ENV['API_KEY'],
                            :dry_run        => ENV['DRY_RUN'])
  end

  task :deploy_with_environment => [:environment, :deploy]

  task :log_stdout do
    require 'logger'
    RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)
  end

  namespace :heroku do
    desc "Install Heroku deploy notifications addon"
    task :add_deploy_notification => [:environment] do
      def heroku_var(var, app_name, default = nil)
        app = app_name ? "--app #{app_name}" : ''
        result = Bundler.with_clean_env { `heroku config:get #{var} #{app} 2> /dev/null`.strip }
        result.split.find(lambda { default }) {|x| x =~ /\S/ }
      end

      heroku_rails_env = heroku_var('RAILS_ENV', ENV['APP'], Honeybadger.configuration.environment_name)
      heroku_api_key = heroku_var('HONEYBADGER_API_KEY', ENV['APP'], Honeybadger.configuration.api_key)

      unless heroku_api_key =~ /\S/ && heroku_rails_env =~ /\S/
        puts "WARNING: We were unable to detect the configuration from your Heroku environment."
        puts "Your Heroku application environment may not be configured correctly."
        puts "Have you configured multiple Heroku apps? Try using APP=[app name]'" unless ENV['APP']
        exit
      end

      command = %Q(heroku addons:add deployhooks:http --url="https://api.honeybadger.io/v1/deploys?deploy[environment]=#{heroku_rails_env}&deploy[local_username]={{user}}&deploy[revision]={{head}}&api_key=#{heroku_api_key}"#{ENV['APP'] ? " --app #{ENV['APP']}" : ''})

      puts "\nRunning:\n#{command}\n"
      puts `#{command}`
    end
  end
end
