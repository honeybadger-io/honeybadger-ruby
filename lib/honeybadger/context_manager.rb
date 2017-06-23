module Honeybadger
  class ContextManager

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

    # Internal accessors

    def set_context(hash)
      raise TypeError, "no implicit conversion of #{hash.class.name} into Hash" unless hash.respond_to?(:to_hash)

      @mutex.synchronize do
        @context ||= []
        @context.push(hash)
      end

      return nil unless block_given?

      begin
        yield
        nil
      ensure
        @mutex.synchronize { @context.delete(hash) }
      end
    end

    def get_context
      @mutex.synchronize do
        return nil unless @context
        @context.reduce({}) {|a,e| a.update(e) }
      end
    end

    def set_rack_env(env)
      @mutex.synchronize { @rack_env = env }
    end

    def get_rack_env
      @mutex.synchronize { @rack_env }
    end

    private

    attr_accessor :custom, :rack_env

    def _initialize
      @mutex.synchronize do
        @context = nil
        @rack_env = nil
      end
    end

  end
end
