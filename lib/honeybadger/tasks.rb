namespace :honeybadger do
  def warn_task_moved(old_name, new_name = old_name)
    puts "This task was moved to the CLI in honeybadger 2.0. To learn more, run `honeybadger help #{new_name}`."
  end

  desc "Verify your gem installation by sending a test exception to the honeybadger service"
  task :test do
    warn_task_moved('test')
  end

  desc "Notify Honeybadger of a new deploy."
  task :deploy do
    warn_task_moved('deploy')
  end
end
