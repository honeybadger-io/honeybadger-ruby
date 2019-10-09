require 'honeybadger/plugin'
require 'honeybadger/util/lambda'

module Honeybadger
  module Plugins
    # @api private
    Plugin.register :lambda do
      requirement { Util::Lambda.lambda_execution? }

      execution do
        config[:sync] = true
        (config[:before_notify] ||= []) << lambda do |notice|
          data = Util::Lambda.normalized_data

          notice.component = data["function"]
          notice.action = data["handler"]
          notice.details["Lambda Details"] = data

          if (trace_id = Util::Lambda.trace_id)
            notice.context[:lambda_trace_id] = trace_id
          end
        end
      end
    end
  end
end
