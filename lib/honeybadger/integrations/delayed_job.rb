module Honeybadger
  Dependency.register do
    requirement { defined?(::Delayed::Plugin) }
    requirement { defined?(::Delayed::Worker.plugins) }
    requirement do
      if delayed_job_honeybadger = defined?(::Delayed::Plugins::Honeybadger)
        Honeybadger.write_verbose_log("Support for Delayed Job has been moved " \
                                      "to the honeybadger gem. Please remove " \
                                      "delayed_job_honeybadger from your " \
                                      "Gemfile.", :warn)
      end
      !delayed_job_honeybadger
    end

    injection do
      require 'honeybadger/integrations/delayed_job/plugin'
      ::Delayed::Worker.plugins << Integrations::DelayedJob::Plugin
    end
  end
end
