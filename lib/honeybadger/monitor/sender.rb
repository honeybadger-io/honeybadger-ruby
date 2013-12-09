module Honeybadger
  module Monitor
    class Sender < Honeybadger::Sender
      def send_metrics(data)
        return unless Honeybadger.configuration.metrics?

        if !Honeybadger.configuration.features['metrics']
          log(:info, "The optional metrics feature is not enabled for your account.  Try restarting your app or contacting support@honeybadger.io if your subscription includes this feature.")
          Honeybadger.configuration.metrics = false
          return nil
        end

        response = rescue_http_errors do
          http_connection.post('/v1/metrics', data.to_json, http_headers)
        end

        if Net::HTTPSuccess === response
          true
        else
          Honeybadger.configuration.features['metrics'] = false if Net::HTTPForbidden === response
          log(:error, "Metrics Failure: #{response.class}", response, data)
          false
        end
      rescue => e
        log(:error, "[Honeybadger::Monitor::Sender#send_metrics] Error: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
        true
      end

    end
  end
end
