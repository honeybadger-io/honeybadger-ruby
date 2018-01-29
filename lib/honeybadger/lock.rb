module Honeybadger
  # @api private
  # The Lock class is used to manage Honeybadger's initialization status.
  class Lock
    @lock = Mutex.new
    @status = nil

    class << self
      def init_status=(status)
        @lock.synchronize { @status = status }
      end

      def init_status
        @lock.synchronize { @status }
      end

      def initialized?
        !!init_status
      end
    end
  end
end
