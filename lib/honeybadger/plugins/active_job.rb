module Honeybadger
  module Plugins
    module ActiveJob

      module Installer
        def self.included(base)
          pp "base #{base}"
          base.send(:alias_method, :perform, :perform_without_honeybadger)
          base.send(:alias_method, :perform_with_honeybadger, :perform)
        end

        def perforn_with_honeybadger
          perform_without_honeybadger
        rescue => exception
          pp "WE HERE"
          Honeybadger.notify(e, parameters: { job_arguments: @job_data }, sync: true)
          raise
        end

      end


      Plugin.register {
        requirement { defined?(::Rails.application) && ::Rails.application }
        requirement { 
          ::Rails.application.config.active_job[:queue_adapter] == :async # || ::Rails.application.config.active_job[:queue_adapter] == :inline || ::Rails.application.config.active_job[:queue_adapter] == :test
        }

        execution {
          adapter = ::Rails.application.config.active_job[:queue_adapter]  
          pp "ADAPTER: #{adapter.inspect}"
          if adapter == :async
            pp "HELLO"
            begin
              ::ActiveJob::Base.set_callback :execute, :around do |param, block|
                pp param, block
              end
            rescue => e
              pp e.stacktrace
            end
              pp "AFTER"
            # ::ActiveJob::QueueAdapters::AsyncAdapter::JobWrapper.send(:include, Installer)
          end
        }
      }
    end
  end

end