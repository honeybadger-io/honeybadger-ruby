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
          Fiber[context_key] = (existing || EMPTY_CONTEXT).merge(new_context)
          yield
        ensure
          Fiber[context_key] = existing
        end
      else
        Fiber[context_key] = (Fiber[context_key] || EMPTY_CONTEXT).merge(new_context)
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

  # @api private
  class CollectionManager
    include Enumerable
    extend Forwardable

    EMPTY_COLLECTION = [].freeze

    def initialize(context_key)
      @context_key = context_key
    end

    attr_reader :context_key

    def push(...)
      Fiber[context_key] = (Fiber[context_key] || []).dup.push(...)
    end
    alias_method :<<, :push

    def pop(...)
      Fiber[context_key] = (Fiber[context_key] || []).dup
      Fiber[context_key].pop(...)
    end

    def shift(...)
      Fiber[context_key] = (Fiber[context_key] || []).dup
      Fiber[context_key].shift(...)
    end

    def get_collection
      Fiber[context_key] || EMPTY_COLLECTION
    end
    alias_method :to_a, :get_collection

    # Read-only delegators
    def_delegators :get_collection, :each, :last

    def clear
      Fiber[context_key] = nil
    end
  end

  BreadcrumbsCollection = CollectionManager.new(:__hb_breadcrumbs)
end
