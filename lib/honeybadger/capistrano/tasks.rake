after 'deploy:finishing', 'honeybadger:deploy'

namespace :honeybadger do
  desc 'Notify Honeybadger of the deployment.'
  task :deploy => :env do
    if server = fetch(:honeybadger_server)
      on server do |host|
        info 'Notifying Honeybadger of deploy.'

        executable = RUBY_PLATFORM.downcase.include?('mswin') ? fetch(:rake, :'rake.bat') : fetch(:rake, :rake)
        rake_task  = fetch(:honeybadger_deploy_task, 'honeybadger:deploy')

        options = [rake_task]

        if fetch(:honeybadger_async_notify, false)
          ::SSHKit.config.command_map.prefix[:rake].push(:nohup)
          options << '>> /dev/null 2>&1 &'
        end

        within release_path do
          execute executable, options
        end

        info 'Honeybadger notification complete.'
      end
    end
  end

  desc 'Setup ENV for Honeybadger deploy rake task.'
  task :env do
    server = fetch(:honeybadger_server) do
      s = primary(:app)
      set(:honeybadger_server, s.select?({ :exclude => :no_release }) ? s : nil)
    end

    if server
      on server do |host|
        rails_env       = fetch(:rails_env, "production")
        honeybadger_env = fetch(:honeybadger_env, rails_env)
        repository      = fetch(:repo_url)
        local_user      = fetch(:honeybadger_user, ENV['USER'] || ENV['USERNAME'])
        api_key         = fetch(:honeybadger_api_key, ENV['HONEYBADGER_API_KEY'] || ENV['API_KEY'])
        revision        = fetch(:current_revision) do
          within(repo_path) do
            capture("cd #{repo_path} && git rev-parse --short HEAD")
          end
        end

        env = ["RAILS_ENV=#{rails_env}", "TO=#{honeybadger_env}", "REVISION=#{revision}", "REPO=#{repository}", "USER=#{local_user}"]
        env << "API_KEY=#{api_key}" if api_key
        ::SSHKit.config.command_map.prefix[:rake].unshift(*env)
      end
    end
  end
end
