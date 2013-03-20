# Defines deploy:notify_honeybadger which will send information about the deploy to Honeybadger.
require 'capistrano'

module Honeybadger
  module Capistrano
    def self.load_into(configuration)
      configuration.load do
        after "deploy",            "honeybadger:deploy"
        after "deploy:migrations", "honeybadger:deploy"

        namespace :honeybadger do
          desc <<-DESC
            Notify Honeybadger of the deployment by running the notification on the REMOTE machine.
              - Run remotely so we use remote API keys, environment, etc.
          DESC
          task :deploy, :except => { :no_release => true } do
            rails_env = fetch(:rails_env, "production")
            honeybadger_env = fetch(:honeybadger_env, fetch(:rails_env, "production"))
            rake_task = fetch(:honeybadger_deploy_task, 'honeybadger:deploy')
            local_user = ENV['USER'] || ENV['USERNAME']
            executable = RUBY_PLATFORM.downcase.include?('mswin') ? fetch(:rake, 'rake.bat') : fetch(:rake, 'rake')
            assync_notify = fetch(:honeybadger_assync_notify, false)
            directory = configuration.current_release
            notify_command = "cd #{directory};"
            notify_command << " nohup" if assync_notify
            notify_command << " #{executable} RAILS_ENV=#{rails_env} #{rake_task} TO=#{honeybadger_env} REVISION=#{current_revision} REPO=#{repository} USER=#{local_user}"
            notify_command << " DRY_RUN=true" if dry_run
            notify_command << " API_KEY=#{ENV['API_KEY']}" if ENV['API_KEY']
            notify_command << " >> /dev/null 2>&1 &" if assync_notify
            logger.info "Notifying Honeybadger of Deploy (#{notify_command})"
            if configuration.dry_run
              logger.info "DRY RUN: Notification not actually run."
            else
              result = ""
              run(notify_command, :once => true, :pty => false) { |ch, stream, data| result << data }
              # TODO: Check if SSL is active on account via result content.
            end
            logger.info "Honeybadger Notification Complete."
          end
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Honeybadger::Capistrano.load_into(Capistrano::Configuration.instance)
end
