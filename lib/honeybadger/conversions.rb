module Honeybadger
  module Conversions
    module_function

    # Internal: Coerce context into a Hash.
    #
    # context - The context object.
    #
    # Returns the Hash context.
    def Context(object)
      object = object.to_honeybadger_context if object.respond_to?(:to_honeybadger_context)
      Hash(object)
    end
  end
end
