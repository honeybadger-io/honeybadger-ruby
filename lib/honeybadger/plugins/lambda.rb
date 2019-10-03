require 'honeybadger/plugin'
require 'honeybadger/util/lambda'

module Honeybadger
  module Plugins
    # @api private
    Plugin.register :lambda do
      requirement { Util::Lambda.lambda_execution? }

      execution do
        Honeybadger.configure do |config|
          config.force_sync = true
          config.before_notify do |notice|
            notice.update_output do |json|
              json[:lambda] = Util::Lambda.normalized_data
            end
          end
        end
      end
    end
  end
end
