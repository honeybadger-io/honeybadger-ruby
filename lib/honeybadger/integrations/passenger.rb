module Honeybadger
  Dependency.register do
    requirement { defined?(::PhusionPassenger) }
    requirement { defined?(::Honeybadger::Monitor) }

    injection do
      ::PhusionPassenger.on_event(:starting_worker_process) do |forked|
        Honeybadger.write_verbose_log('Starting passenger worker process')
        Honeybadger::Monitor.worker.fork if forked
      end

      ::PhusionPassenger.on_event(:stopping_worker_process) do
        Honeybadger.write_verbose_log('Stopping passenger worker process')
        Honeybadger::Monitor.worker.stop
      end
    end
  end
end
