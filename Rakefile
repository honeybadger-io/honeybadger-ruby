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
  separator_index = ARGV.index("--")
  extra_args = separator_index ? " #{ARGV[(separator_index + 1)..].join(" ")}" : ""
  sh("#{cmd}#{extra_args}")
end

def run_specs(dirs)
  if RUBY_ENGINE == "jruby"
    isolated_dirs, other_dirs = dirs.partition { |d| d == SPEC_DIRS[:integrations] }
    isolated_dirs.map do |dir|
      # Integration specs must run in separate processes
      sh_with_args "find #{dir} -name '*_spec.rb' | xargs -I {} bundle exec rspec {}"
    end
    sh_with_args "bundle exec rspec #{other_dirs.join(" ")}" if other_dirs.any?
  else
    sh_with_args "forking-test-runner #{dirs.join(" ")} --rspec --parallel 4"
  end
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

  run_specs(dirs)
end

desc "Alias for spec"
task test: :spec

desc "Alias for spec (default task)"
task default: :spec
