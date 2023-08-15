module Honeybadger
  # @api private
  module Conversions
    module_function
    MAX_CONTEXT_DEPTH = 5

    # Convert context into a Hash.
    #
    # @param [Object] object The context object.
    #
    # @return [Hash] The hash context.
    def Context(object, depth = 1)
      object = object.to_honeybadger_context if object.respond_to?(:to_honeybadger_context)
      object = Hash(object)
      object = object.transform_values do |value|
        if value&.respond_to?(:to_honeybadger_context)
          Context(value, depth + 1)
        else
          value
        end
      end if depth < MAX_CONTEXT_DEPTH
      object
    end
  end
end
