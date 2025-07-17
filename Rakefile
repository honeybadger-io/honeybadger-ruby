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

require "rspec/core/rake_task"
namespace :spec do
  desc "Run unit specs"
  RSpec::Core::RakeTask.new(:units) do |t|
    t.pattern = "spec/unit/**/*_spec.rb"
    t.rspec_opts = "--require spec_helper"
  end

  desc "Run integration specs"
  RSpec::Core::RakeTask.new(:integrations) do |t|
    t.pattern = "spec/integration/**/*_spec.rb"
    t.rspec_opts = "--require spec_helper"
  end

  desc "Run feature specs"
  RSpec::Core::RakeTask.new(:features) do |t|
    t.pattern = "spec/features/**/*_spec.rb"
    t.rspec_opts = "--require spec_helper"
  end

  desc "Runs unit and feature specs"
  task all: [:units, :integrations, :features]
end

desc "Alias for spec:all (default task)"
task spec: :"spec:all"
task test: :spec
task default: :spec
