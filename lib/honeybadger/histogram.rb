require 'honeybadger/metric'

module Honeybadger
  class Histogram < Metric
    DEFAULT_BINS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]

    def record(value)
      @sampled += 1
      @bin_counts ||= Hash.new(0)
      @bin_counts[find_bin(value)] += 1
    end

    def find_bin(value)
      bin = bins.find {|b| b >= value  }
      bin = "+Inf" if bin.nil?
      bin
    end

    def bins
      @attributes.fetch(:bins, DEFAULT_BINS).sort
    end

    def payloads
      [{bins: @bin_counts}]
    end
  end
end
