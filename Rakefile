require 'rubygems'
require 'bundler/setup'
require 'appraisal'
require 'honeybadger/version'
require_relative 'tools/release'

NAME = Dir['*.gemspec'].first.split('.').first.freeze
VERSION = Honeybadger::VERSION
GEM_FILE = "#{NAME}-#{VERSION}.gem".freeze
GEMSPEC_FILE = "#{NAME}.gemspec".freeze

require 'rspec/core/rake_task'
namespace :spec do
  desc 'Run unit specs'
  RSpec::Core::RakeTask.new(:units) do |t|
    t.pattern = 'spec/unit/**/*_spec.rb'
    t.rspec_opts = '--require spec_helper'
  end

  desc 'Run integration specs'
  RSpec::Core::RakeTask.new(:integrations) do |t|
    t.pattern = 'spec/integration/**/*_spec.rb'
    t.rspec_opts = '--require spec_helper'
  end

  desc 'Run feature specs'
  RSpec::Core::RakeTask.new(:features) do |t|
    t.pattern = 'spec/features/**/*_spec.rb'
    t.rspec_opts = '--require spec_helper'
  end

  desc 'Runs unit and feature specs'
  task all: [:units, :integrations, :features]
end

desc 'Alias for spec:all (default task)'
task spec: :'spec:all'
task test: :spec
task default: :spec

desc "Bump CHANGELOG v#{Release.next_version(VERSION)}"
task :bump_changelog, [:version] do |_, args|
  Release.bump_changelog(args[:version])
end

desc "Bump v#{VERSION} to v#{Release.next_version(VERSION)}"
task :bump do
  Release.bump
end

desc "Create tag v#{VERSION} and build and push #{GEM_FILE} to Rubygems"
task :release => :build do
  unless `git branch` =~ /^\* master$/
    puts "You must be on the master branch to release!"
    exit!
  end
  sh "git commit --allow-empty -a -e -m 'Release #{VERSION}'"
  sh "git tag v#{VERSION}"
  sh "git push origin master"
  sh "git push origin v#{VERSION}"
  sh "gem push pkg/#{GEM_FILE}"
end

desc "Build #{GEM_FILE} into the pkg directory"
task :build do
  sh "mkdir -p pkg"
  sh "gem build #{GEMSPEC_FILE}"
  sh "mv #{GEM_FILE} pkg"
end

require 'rdoc/task'
RDoc::Task.new do |rdoc|
  rdoc.main = 'README.md'
  rdoc.markup = 'tomdoc'
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include('README.md', 'lib/**/*.rb')
end
