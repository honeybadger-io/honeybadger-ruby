module Honeybadger
  module CLI
    module Helpers
      module BackendCmd
        def error_message(response)
          host = config.get(:'connection.host')
          <<-MSG
!! --- Honeybadger request failed --------------------------------------------- !!

We encountered an error when contacting the server:

  #{response.error_message}

To fix this issue, please try the following:

  - Make sure the gem is configured properly.
  - Retry executing this command a few times.
  - Make sure you can connect to #{host} (`curl https://#{host}/v1/notices`).
  - Email support@honeybadger.io for help. Include as much debug info as you
    can for a faster resolution!

!! --- End -------------------------------------------------------------------- !!
MSG
        end
      end
      module Environment
        def fetch_value(options, key)
          options[key] == key ? nil : options[key]
        end
        
        def load_env(options)
          # Initialize Rails when running from Rails root.
          environment_rb = File.join(Dir.pwd, 'config', 'environment.rb')
          if File.exist?(environment_rb)
            load_rails_env_if_allowed(environment_rb, options)
          end
          # Ensure config is loaded (will be skipped if initialized by Rails).
          Honeybadger.config.load!
        end
  
        def load_rails_env_if_allowed(environment_rb, options)
          # Skip Rails initialization according to option flag
          if options.has_key?('skip_rails_load') && fetch_value(options, 'skip_rails_load')
            say("Skipping Rails initialization.")
          else
            load_rails_env(environment_rb)
          end
        end
  
        def load_rails_env(environment_rb)
          begin
            require 'rails'
          rescue LoadError
            # No Rails, so skip loading Rails environment.
            return
          end
          require environment_rb
        end
      end
    end
  end
end
