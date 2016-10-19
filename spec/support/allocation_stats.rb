skipped = true
begin
  if ENV['PERF']
    require 'allocation_stats'
    skipped = false
  end
rescue LoadError
  nil
end

puts 'Skipping AllocationStats.' if skipped

RSpec::Matchers.define :allocate_under do |expected|
  match do |actual|
    return skip('AllocationStats is not available: skipping.') unless defined?(AllocationStats)
    @trace = actual.is_a?(Proc) ? AllocationStats.trace(&actual) : actual
    @trace.new_allocations.size < expected
  end

  def objects
    self
  end

  def supports_block_expectations?
    true
  end

  def output_trace_info(trace)
    trace.allocations(alias_paths: true).group_by(:sourcefile, :sourceline, :class).to_text
  end

  failure_message do |actual|
    "expected under #{ expected } objects to be allocated; got #{ @trace.new_allocations.size }:\n\n" << output_trace_info(@trace)
  end

  description do
    "allocates under #{ expected } objects"
  end
end
