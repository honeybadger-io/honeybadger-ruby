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
    if Honeybadger.start({:api_key => 'badgers', :backend => 'null'})
      1000.times do
        Honeybadger.notify(error_class: 'RubyProf', error_message: 'Profiling Honeybadger -- this should never actually be reported.')
      end
    end
  end

  Honeybadger::Agent.at_exit do
    puts "\n\n"
    puts stats.allocations(alias_paths: true).group_by(*group_by).to_text
  end
}
