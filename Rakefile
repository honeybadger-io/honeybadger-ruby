# frozen_string_literal: true
require "bundler/setup"
require "appraisal"
require "rdoc/task"

SPEC_DIRS = {
  units: "spec/unit/",
  integrations: "spec/integration/",
  cli: "spec/cli/"
}.freeze

RDoc::Task.new do |rdoc|
  rdoc.main = "README.md"
  rdoc.markup = "tomdoc"
  rdoc.rdoc_dir = "doc"
  rdoc.rdoc_files.include("README.md", "lib/**/*.rb")
end

# This lets you pass args to the `sh` command, like this:
# rake spec -- --quiet
def sh_with_args(cmd)
  separator_index = ARGV.index('--')
  extra_args = separator_index ? " #{ARGV[(separator_index + 1)..].join(' ')}" : ""
  sh "#{cmd}#{extra_args}"
end

desc "Run spec suites (defaults to all, e.g., rake spec[units,integrations,cli])"
task :spec, [:suites] do |_t, args|
  suites = args[:suites]&.split(",") || []
  suites += args.extras if args.extras.any?

  dirs = if suites.empty?
    SPEC_DIRS.values
  else
    suites.map do |suite|
      suite = suite.strip.to_sym
      SPEC_DIRS[suite] || abort("Unknown suite: #{suite}. Valid options: #{SPEC_DIRS.keys.join(', ')}")
    end
  end

  sh_with_args "forking-test-runner #{dirs.join(' ')} --rspec --parallel 4"
end

desc "Alias for spec"
task test: :spec

desc "Alias for spec (default task)"
task default: :spec
