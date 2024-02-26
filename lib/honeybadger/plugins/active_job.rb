module Honeybadger
  module Plugins
    module ActiveJob
            
      Plugin.register {
        requirement { defined?(::Rails.application) && ::Rails.application }
        requirement {
          ::Rails.application.config.respond_to?(:active_job) &&
            ::Rails.application.config.active_job[:queue_adapter] == :async
        }
        
        execution {
          ::ActiveJob::Base.class_eval do |base| 
            base.set_callback :perform, :around do |param, block|
              Honeybadger.clear!
              begin
                block.call
              rescue => error
                Honeybadger.notify(error, parameters: { job_arguments: self.arguments })
                raise error
              end
            end
          end          
        }
      }
    end
  end

end
