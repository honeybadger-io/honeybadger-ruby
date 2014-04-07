require "honeybadger/array"
require "honeybadger/monitor/sender"
require "honeybadger/monitor/worker"
require "honeybadger/monitor/railtie" if defined?(Rails)
require "honeybadger/monitor/trace" if defined?(Rails)

module Honeybadger
  module Monitor
    class << self

      def worker
        Worker.instance
      end

    end
  end
end
