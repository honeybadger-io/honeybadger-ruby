module Honeybadger
  module Conversions
    module_function

    # Internal: Coerce context into a Hash.
    #
    # context - The context object.
    #
    # Returns the Hash context.
    def Context(context)
      context = exception.to_honeybadger_context if context.respond_to?(:to_honeybadger_context)
      Hash(context)
    end
  end
end
