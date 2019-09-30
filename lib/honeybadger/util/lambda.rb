module Honeybadger
  module Util
    class Lambda
      AWS_ENV_MAP = {
        "_HANDLER" => "handler",
        "AWS_REGION" => "region",
        "AWS_EXECUTION_ENV" => "runtime",
        "AWS_LAMBDA_FUNCTION_NAME" => "function",
        "AWS_LAMBDA_FUNCTION_MEMORY_SIZE" => "memory",
        "AWS_LAMBDA_FUNCTION_VERSION" => "version",
        "AWS_LAMBDA_LOG_GROUP_NAME" => "log_group",
        "AWS_LAMBDA_LOG_STREAM_NAME" => "log_name"
      }.freeze

      def self.lambda_execution?
        !!ENV["AWS_EXECUTION_ENV"]
      end

      def self.normalized_data
        AWS_ENV_MAP.each_with_object({}) do |(k, v), memo|
          memo[v] = ENV[k] if ENV[k]
        end
      end
    end
  end
end
