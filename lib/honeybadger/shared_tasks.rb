namespace :honeybadger do
  desc "Notify Honeybadger of a new deploy."
  task :deploy => :environment do
    require 'honeybadger_tasks'
    HoneybadgerTasks.deploy(:environment    => ENV['TO'],
                            :revision       => ENV['REVISION'],
                            :repository     => ENV['REPO'],
                            :local_username => ENV['USER'],
                            :api_key        => ENV['API_KEY'],
                            :dry_run        => ENV['DRY_RUN'])
  end

  task :log_stdout do
    require 'logger'
    RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)
  end

  namespace :heroku do
    desc "Install Heroku deploy notifications addon"
    task :add_deploy_notification => [:environment] do

      def heroku_var(var)
        `heroku config | grep -E "#{var.upcase}" | awk '{ print $3; }'`.strip
      end

      heroku_rails_env = heroku_var("rails_env")
      heroku_api_key = heroku_var("(honeybadger)_api_key").split.find {|x| x unless x.blank?} ||
        Honeybadger.configuration.api_key

      command = %Q(heroku addons:add deployhooks:http --url="https://api.honeybadger.io/deploys.txt?deploy[environment]=#{heroku_rails_env}&api_key=#{heroku_api_key}")

      puts "\nRunning:\n#{command}\n"
      puts `#{command}`
    end
  end
end
