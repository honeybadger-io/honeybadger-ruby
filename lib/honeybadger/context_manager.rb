require 'honeybadger/conversions'

module Honeybadger
  # @api private
  class ContextManager
    include Conversions

    def self.current
      Thread.current[:__hb_context_manager] ||= new
    end

    def initialize
      @mutex = Mutex.new
      _initialize
    end

    def clear!
      _initialize
    end

    # Internal helpers


    def set_context(hash, &block)
      local = block_given?
      @mutex.synchronize do
        @global_context ||= {}
        @local_context ||= []

        new_context = Context(hash)

        if local
          @local_context << new_context
        else
          @global_context.update(new_context)
        end
      end

      if local
        begin
          yield
        ensure
          @mutex.synchronize { @local_context&.pop }
        end
      end
    end

    def get_context
      @mutex.synchronize do
        return @global_context unless @local_context

        @global_context.merge(@local_context.inject({}, :merge))
      end
    end

    def set_rack_env(env)
      @mutex.synchronize { @rack_env = env }
    end

    def get_rack_env
      @mutex.synchronize { @rack_env }
    end

    def set_request_id(request_id)
      @mutex.synchronize { @request_id = request_id }
    end

    def get_request_id
      @mutex.synchronize { @request_id }
    end

    private

    attr_accessor :custom, :rack_env, :request_id

    def _initialize
      @mutex.synchronize do
        @global_context = nil
        @local_context = nil
        @rack_env = nil
        @request_id = nil
      end
    end
  end
end
