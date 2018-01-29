namespace :honeybadger do
  def warn_task_moved(old_name, new_cmd = "honeybadger help #{old_name}")
    puts "This task was moved to the CLI in honeybadger 2.0. To learn more, run `#{new_cmd}`."
  end

  desc "Verify your gem installation by sending a test exception to the honeybadger service"
  task :test do
    warn_task_moved('test')
  end

  desc "Notify Honeybadger of a new deploy."
  task :deploy do
    warn_task_moved('deploy')
  end

  namespace :heroku do
    desc "Install Heroku deploy notifications addon"
    task :add_deploy_notification do
      warn_task_moved('heroku:add_deploy_notification', 'honeybadger heroku help install_deploy_notification')
    end
  end

  # Meta task to initialize honeybadger before any rake tasks are started
  task :init do
    # TODO: we need to remove the duplication between this and lib/honeybadger
    if defined?(::Rails::Railtie)
      ::Honeybadger::Init::Rails::Railtie.rails_init(:without_env)
    end
  end
end

# This is so that we can enhance tasks after all of them are loaded
import(File.expand_path "../enhance_rake_tasks.rb", __FILE__)
