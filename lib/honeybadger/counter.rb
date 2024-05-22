require 'honeybadger/metric'

module Honeybadger
  class Counter < Metric
    def count(by=1)
      return unless value

      @sampled += 1

      @counter ||= 0
      @counter = @counter + by
    end

    def payloads
      [{ counter: @counter }]
    end
  end
end
