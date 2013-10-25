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

        response = client.post do |p|
          p.url "/v1/metrics"
          p.body = data.to_json
        end

        if response.success?
          true
        else
          Honeybadger.configuration.features['metrics'] = false if response.status == 403
          log(:error, "Metrics Failure", response, data)
          false
        end

      rescue => e
        log(:error, "[Honeybadger::Monitor::Sender#send_metrics] Error: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
        true
      end

    end
  end
end
