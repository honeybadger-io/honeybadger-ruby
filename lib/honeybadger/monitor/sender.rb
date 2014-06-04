module Honeybadger
  module Monitor
    class Sender < Honeybadger::Sender
      def send_metrics(data)
        return unless Honeybadger.configuration.metrics?
        return unless Honeybadger.configuration.features['metrics']

        response = rescue_http_errors do
          http_connection.post('/v1/metrics', data.to_json, http_headers)
        end

        if Net::HTTPSuccess === response
          log(:info, "Metrics Success: #{response.class}", response, data) if Honeybadger.configuration.debug
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

      def send_traces(data)
        return unless Honeybadger.configuration.traces?
        return unless Honeybadger.configuration.features['traces']

        response = rescue_http_errors do
          http_connection.post('/v1/traces', data.to_json, http_headers)
        end

        if Net::HTTPSuccess === response
          log(:info, "Traces Success: #{response.class}", response, data) if Honeybadger.configuration.debug
          true
        else
          Honeybadger.configuration.features['traces'] = false if Net::HTTPForbidden === response
          log(:error, "Traces Failure: #{response.class}", response, data)
          false
        end
      rescue => e
        log(:error, "[Honeybadger::Monitor::Sender#send_traces] Error: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
        true
      end

    end
  end
end
