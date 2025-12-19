require "honeybadger/conversions"

module Honeybadger
  # @api private
  class ContextManager
    include Conversions

    EMPTY_CONTEXT = {}.freeze

    def initialize(context_key)
      @context_key = context_key
    end

    attr_reader :context_key

    def set_context(hash, &block)
      new_context = Context(hash)

      if block_given?
        existing = Fiber[context_key]
        begin
          Fiber[context_key] = (existing || {}).merge(new_context)
          yield
        ensure
          Fiber[context_key] = existing
        end
      else
        Fiber[context_key] = (Fiber[context_key] || {}).merge(new_context)
      end
    end
    alias_method :context, :set_context

    def get_context
      Fiber[context_key] || EMPTY_CONTEXT
    end

    def clear
      Fiber[context_key] = nil
    end
    alias_method :clear!, :clear
  end

  # @api private
  ErrorContext = ContextManager.new(:__hb_error_context)

  # @api private
  EventContext = ContextManager.new(:__hb_event_context)

  # @api private
  ExecutionContext = ContextManager.new(:__hb_execution_context)
end
