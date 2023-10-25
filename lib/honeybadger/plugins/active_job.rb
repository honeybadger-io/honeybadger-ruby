module Honeybadger
  module Plugins
    module ActiveJob
            
      Plugin.register {
        requirement { defined?(::Rails.application) && ::Rails.application }
        requirement { 
          ::Rails.application.config.active_job[:queue_adapter] == :async
        }
        
        execution {
          ::ActiveJob::Base.class_eval do |base| 
            base.set_callback :perform, :around do |param, block|
              begin
                Honeybadger.flush {
                  block.call
                }
              rescue => e
                Honeybadger.notify(e, parameters: { job_arguments: self.arguments }, sync: true)
                raise
              end
            end
          end          
        }
      }
    end
  end

end