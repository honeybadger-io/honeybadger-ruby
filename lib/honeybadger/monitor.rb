require "honeybadger/array"
require "honeybadger/monitor/sender"
require "honeybadger/monitor/worker"
require "honeybadger/monitor/trace"
require "honeybadger/monitor/railtie" if defined?(Rails::Railtie)

module Honeybadger
  module Monitor
    class << self

      def worker
        Worker.instance
      end

    end
  end
end
