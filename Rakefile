# frozen_string_literal: true

require "rubygems"
require "bundler/setup"
require "bump"
require "appraisal"
require "honeybadger/version"
require_relative "tools/release"

NAME = Dir["*.gemspec"].first.split(".").first.freeze
VERSION = Honeybadger::VERSION
GEM_FILE = "#{NAME}-#{VERSION}.gem"
GEMSPEC_FILE = "#{NAME}.gemspec"

require "rdoc/task"
RDoc::Task.new do |rdoc|
  rdoc.main = "README.md"
  rdoc.markup = "tomdoc"
  rdoc.rdoc_dir = "doc"
  rdoc.rdoc_files.include("README.md", "lib/**/*.rb")
end

namespace :spec do
  desc "Run unit specs"
  task :units do
    sh "forking-test-runner spec/unit/ --rspec --parallel 4 --quiet"
  end

  desc "Run integration specs"
  task :integrations do
    sh "forking-test-runner spec/integration/ --rspec --parallel 4 --quiet"
  end

  desc "Run CLI specs"
  task :cli do
    sh "forking-test-runner spec/cli/ --rspec --parallel 4 --quiet"
  end

  desc "Runs all specs"
  task :all do
    sh "forking-test-runner spec/ --rspec --parallel 4 --quiet"
  end
end

desc "Alias for spec:all (default task)"
task spec: :"spec:all"
task test: :spec
task default: :spec
