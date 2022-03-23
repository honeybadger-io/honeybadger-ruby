require 'honeybadger/plugin'
require 'honeybadger/util/lambda'

module Honeybadger
  module Plugins
    module LambdaExtension
      unless self.respond_to?(:hb_lambda)
        # Decorator for Lambda handlers so exceptions can be automatically captured
        #
        # Usage:
        #
        # hb_lambda def my_lambda_handler(event:, context:)
        #   # Handler code
        # end
        #
        # class Lambda
        #   hb_lambda def self.my_lambda_handler(event:, context:)
        #     # Handler code
        #   end
        # end
        def hb_lambda(handler_name)
          original_method = method(handler_name)
          self.define_singleton_method(handler_name) do |event:, context:|
            Honeybadger.context({ aws_request_id: context.aws_request_id }) if context.respond_to?(:aws_request_id)

            original_method.call(event: event, context: context)
          rescue => e
            Honeybadger.notify(e)
            # Bubble the error up to Lambda, but disable other reporting to avoid duplicates in local emulated environments
            # Since the process immediately exits, nothing else is affected
            Honeybadger.config[:'exceptions.notify_at_exit'] = false
            raise
          end
        end
      end
    end


    # @api private
    Plugin.register :lambda do
      requirement { Util::Lambda.lambda_execution? }

      execution do
        config[:sync] = true

        # AWS Lambda handlers may be top-level methods or class methods
        # See https://docs.aws.amazon.com/lambda/latest/dg/ruby-handler.html
        # So we provide a decorator for both cases
        main = TOPLEVEL_BINDING.eval("self")
        main.extend(LambdaExtension)
        Class.include(LambdaExtension)

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
