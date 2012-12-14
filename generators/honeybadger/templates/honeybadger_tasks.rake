# Don't load anything when running the gems:* tasks.
# Otherwise, honeybadger will be considered a framework gem.
# https://thoughtbot.lighthouseapp.com/projects/14221/tickets/629
unless ARGV.any? {|a| a =~ /^gems/}

  Dir[File.join(Rails.root, 'vendor', 'gems', 'honeybadger-*')].each do |vendored_notifier|
    $: << File.join(vendored_notifier, 'lib')
  end

  begin
    require 'honeybadger/tasks'
  rescue LoadError => exception
    namespace :honeybadger do
      %w(deploy test log_stdout).each do |task_name|
        desc "Missing dependency for honeybadger:#{task_name}"
        task task_name do
          $stderr.puts "Failed to run honeybadger:#{task_name} because of missing dependency."
          $stderr.puts "You probably need to run `rake gems:install` to install the honeybadger gem"
          abort exception.inspect
        end
      end
    end
  end

end
