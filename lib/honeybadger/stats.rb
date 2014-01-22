module Honeybadger
  class Stats
    HAS_MEM = File.exists?("/proc/meminfo")
    HAS_LOAD = File.exists?("/proc/loadavg")

    class << self
      def all
        { :mem => memory, :load => load }
      end

      # From https://github.com/bloopletech/webstats/blob/master/server/data_providers/mem_info.rb
      def memory
        out = {}
        if HAS_MEM
          out[:total], out[:free], out[:buffers], out[:cached] = IO.readlines("/proc/meminfo")[0..4].map { |l| l =~ /^.*?\: +(.*?) kB$/; ($1.to_i / 1024.0).to_f }
          out[:free_total] = out[:free] + out[:buffers] + out[:cached]
        end
        out
      end

      # From https://github.com/bloopletech/webstats/blob/master/server/data_providers/cpu_info.rb
      def load
        out = {}
        out[:one], out[:five], out[:fifteen] = IO.read("/proc/loadavg").split(' ', 4).map(&:to_f) if HAS_LOAD
        out
      end
    end
  end
end
