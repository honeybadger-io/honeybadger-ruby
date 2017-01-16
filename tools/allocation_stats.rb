require 'allocation_stats'
require 'honeybadger'
require 'benchmark'

group_by = if ENV['GROUP']
             ENV['GROUP'].split(',').lazy.map(&:strip).map(&:to_sym).freeze
           else
             [:sourcefile, :sourceline, :class].freeze
           end

puts Benchmark.measure {
  stats = AllocationStats.trace do
    Honeybadger.configure do |config|
      config.api_key = 'badgers'
      config.backend = 'null'
    end

    1000.times do
      Honeybadger.notify(error_class: 'RubyProf', error_message: 'Profiling Honeybadger -- this should never actually be reported.')
    end
  end

  Honeybadger.flush

  puts "\n\n"
  puts stats.allocations(alias_paths: true).group_by(*group_by).to_text
}
