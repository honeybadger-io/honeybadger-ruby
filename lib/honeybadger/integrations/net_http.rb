module Honeybadger
  module Integrations
    module NetHttp
      module Instrumentation
        def self.included(base)
          base.send(:alias_method, :request_without_honeybadger, :request)
          base.send(:alias_method, :request, :request_with_honeybadger)
        end

        def request_with_honeybadger(*args, &block)
          request = args[0]
          uri = request.path.match(%r{https?://}) ? URI(request.path) : URI("http#{use_ssl? ? 's' : ''}://#{address}:#{port}#{request.path}")

          if uri.host.match("honeybadger.io")
            return request_without_honeybadger(*args, &block)
          end

          ActiveSupport::Notifications.instrument("net_http.request", { uri: uri, method: request.method }) do
            request_without_honeybadger(*args, &block)
          end
        end
      end
    end
  end

  Dependency.register do
    requirement { defined?(::ActiveSupport::Notifications) }
    requirement { defined?(::Net::HTTP) }
    requirement { Honeybadger.configuration.traces? }

    injection { ::Net::HTTP.send(:include, Integrations::NetHttp::Instrumentation) }
  end
end
