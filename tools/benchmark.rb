# Public: Standalone benchmark, useful for profiling JRuby.
#
# Examples:
#
#   To profile object allocations using the JVM's built-in profiler:
#
#     bundle exec jruby -J-Xrunhprof spec/benchmark.rb

require "honeybadger"
require "benchmark"

benchmark = Benchmark.measure do
  if Honeybadger.start({api_key: "badgers", backend: "null"})
    1000.times do
      Honeybadger.notify(error_class: "RubyProf", error_message: "Profiling Honeybadger -- this should never actually be reported.")
    end
  end
end

puts benchmark
