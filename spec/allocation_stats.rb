require 'allocation_stats'
require 'honeybadger'
require 'benchmark'
require 'sham_rack'

ShamRack.at('api.honeybadger.io', 443).stub.tap do |app|
  app.register_resource('/v1/notices/', %({"id":"123456789"}), "application/json")
  app.register_resource('/v1/ping/', %({"features":{"notices":true,"feedback":true}, "limit":null}), "application/json")
end

group_by = if ENV['GROUP']
             ENV['GROUP'].split(',').lazy.map(&:strip).map(&:to_sym).freeze
           else
             [:sourcefile, :sourceline, :class].freeze
           end

puts Benchmark.measure {
  stats = AllocationStats.trace do
    Honeybadger.configure do |config|
      config.api_key = 'badgers'
      config.environment_name = 'production'
      config.development_environments = []
    end

    1000.times do
      Honeybadger.notify(error_class: 'AllocationStats', error_message: 'Profiling Honeybadger -- this should never actually be reported.')
    end
  end

  puts stats.allocations(alias_paths: true).group_by(*group_by).to_text
  puts "\n\n"
}
