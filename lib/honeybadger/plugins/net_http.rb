require 'honeybadger/plugin'
require 'honeybadger/trace'

module Honeybadger
  module Plugins
    module NetHttp
      module Instrumentation

        def request(*args, &block)
          request = args[0]
          uri = request.path.to_s.match(%r{https?://}) ? URI(request.path) : URI("http#{use_ssl? ? 's' : ''}://#{address}:#{port}#{request.path}")

          if uri.host.to_s.match("honeybadger.io")
            return super(*args, &block)
          end

          ActiveSupport::Notifications.instrument("net_http.request", { :uri => uri, :method => request.method }) do
            # Disable tracing during #request so that additional calls (i.e.
            # when connection wasn't started) don't result in double counting.
            Trace.ignore_events { super(*args, &block) }
          end
        end
      end

      Plugin.register do
        requirement { defined?(::ActiveSupport::Notifications) }
        requirement { defined?(::Net::HTTP) }
        requirement { config[:'traces.enabled'] }

        execution { ::Net::HTTP.send(:prepend,Honeybadger::Plugins::NetHttp::Instrumentation) }
      end
    end
  end
end
