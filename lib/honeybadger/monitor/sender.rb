module Honeybadger
  module Monitor
    class Sender < Honeybadger::Sender
      def send_metrics(data)
        return unless Honeybadger.configuration.metrics?

        if !Honeybadger.configuration.features['metrics']
          log(:info, 'The optional metrics feature is not enabled for your account.  Try restarting your app or contacting support@honeybadger.io if your subscription includes this feature.')
          Honeybadger.configuration.metrics = false
          return nil
        end

        send_request(:metrics, data)
        true
      rescue InvalidResponseError => e
        Honeybadger.configuration.features['metrics'] = false if Net::HTTPForbidden === e.response
        false
      rescue Error
        false
      rescue StandardError => e
        log(:error, "[Honeybadger::Monitor::Sender#send_metrics] Error: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n\t")}")
        false
      end

    end
  end
end
