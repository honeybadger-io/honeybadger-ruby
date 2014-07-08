module Honeybadger
  module Integrations
    module Unicorn
      module AfterForkExtension
        def self.included(base)
          base.send(:alias_method, :init_worker_process_without_honeybadger, :init_worker_process)
          base.send(:alias_method, :init_worker_process, :init_worker_process_with_honeybadger)
        end

        def init_worker_process_with_honeybadger(*args, &block)
          init_worker_process_without_honeybadger(*args, &block).tap do
            Honeybadger::Monitor.worker.fork
          end
        end
      end
    end
  end

  Dependency.register do
    requirement { defined?(::Honeybadger::Monitor) }
    requirement { defined?(::Unicorn::HttpServer) }

    injection { Honeybadger.write_verbose_log('Installing Unicorn integration') }
    injection { ::Unicorn::HttpServer.send(:include, Integrations::Unicorn::AfterForkExtension) }
  end
end
