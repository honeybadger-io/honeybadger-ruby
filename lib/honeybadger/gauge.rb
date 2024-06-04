require 'honeybadger/metric'

module Honeybadger
  class Gauge < Metric
    def record(value)
      return unless value

      @samples += 1

      @total ||= 0
      @total = @total + value

      @min = value if @min.nil? || @min > value
      @max = value if @max.nil? || @max < value
      @avg = @total.to_f / @samples
      @latest = value
    end

    def payloads
      [
        {
          min: @min,
          max: @max,
          avg: @avg,
          latest: @latest
        }
      ]
    end
  end
end
