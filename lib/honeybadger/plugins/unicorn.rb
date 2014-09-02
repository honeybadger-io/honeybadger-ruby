require 'honeybadger/plugin'
require 'honeybadger/agent'

module Honeybadger
  module Plugins
    module Unicorn
      module AfterForkExtension
        def self.included(base)
          base.send(:alias_method, :init_worker_process_without_honeybadger, :init_worker_process)
          base.send(:alias_method, :init_worker_process, :init_worker_process_with_honeybadger)
        end

        def init_worker_process_with_honeybadger(*args, &block)
          init_worker_process_without_honeybadger(*args, &block).tap do
            Honeybadger::Agent.fork
          end
        end
      end

      Plugin.register do
        requirement { defined?(::Unicorn::HttpServer) }

        execution { ::Unicorn::HttpServer.send(:include, AfterForkExtension) }
      end
    end
  end
end
