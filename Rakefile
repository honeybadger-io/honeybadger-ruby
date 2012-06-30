require 'rubygems'
require 'rake'
require 'date'
begin
  require 'cucumber/rake/task'
rescue LoadError
  $stderr.puts "Please install cucumber: `gem install cucumber`"
  exit 1
end

#############################################################################
#
# Helper functions
#
#############################################################################

def name
  @name ||= Dir['*.gemspec'].first.split('.').first
end

def version
  line = File.read("lib/#{name}.rb")[/^\s*VERSION\s*=\s*.*/]
  line.match(/.*VERSION\s*=\s*['"](.*)['"]/)[1]
end

def date
  Date.today.to_s
end

def rubyforge_project
  name
end

def gemspec_file
  "#{name}.gemspec"
end

def gem_file
  "#{name}-#{version}.gem"
end

def replace_header(head, header_name)
  head.sub!(/(\.#{header_name}\s*= ').*'/) { "#{$1}#{send(header_name)}'"}
end

#############################################################################
#
# Standard tasks
#
#############################################################################

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

desc "Generate RCov test coverage and open in your browser"
task :coverage do
  require 'rcov'
  sh "rm -fr coverage"
  sh "rcov test/*_test.rb"
  sh "open coverage/index.html"
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "#{name} #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -r ./lib/#{name}.rb"
end

#############################################################################
#
# Custom tasks (add your own tasks here)
#
#############################################################################

FEATURES = ['sinatra', 'rack', 'metal']

desc 'Default: run unit & acceptance tests.'
task :default => [:test, :vendor_test_gems , "cucumber:rails:all"] + FEATURES

GEM_ROOT = File.dirname(__FILE__).freeze

LOCAL_GEM_ROOT = File.join(GEM_ROOT, 'tmp', 'local_gems').freeze
RAILS_VERSIONS = IO.read('SUPPORTED_RAILS_VERSIONS').strip.split("\n")
LOCAL_GEMS =
  [
    ["rack","1.3.2"],
  ] +
  RAILS_VERSIONS.collect { |version| ['rails', version] } +
  [
    ['sham_rack', nil],
    ['capistrano', nil],
    ['sqlite3-ruby', nil],
    ["therubyracer",nil],
    ["sinatra",nil]
  ]

desc "Vendor test gems: Run this once to prepare your test environment"
task :vendor_test_gems do
  old_gem_path = ENV['GEM_PATH']
  old_gem_home = ENV['GEM_HOME']
  ENV['GEM_PATH'] = LOCAL_GEM_ROOT
  ENV['GEM_HOME'] = LOCAL_GEM_ROOT

  LOCAL_GEMS.each do |gem_name, version|
    gem_file_pattern = [gem_name, version || '*'].compact.join('-')
    version_option = version ? "-v #{version}" : ''
    pattern = File.join(LOCAL_GEM_ROOT, 'gems', "#{gem_file_pattern}")
    existing = Dir.glob(pattern).first
    if existing
      puts "\nskipping #{gem_name} since it's already vendored," +
      "remove it from the tmp directory first."
      next
    end

    command = "gem install -i #{LOCAL_GEM_ROOT} --no-ri --no-rdoc --backtrace #{version_option} #{gem_name}"
    puts "Vendoring #{gem_file_pattern}..."
    unless system("#{command} 2>&1")
      puts "Command failed: #{command}"
      exit(1)
    end
  end

  ENV['GEM_PATH'] = old_gem_path
  ENV['GEM_HOME'] = old_gem_home
end

Cucumber::Rake::Task.new(:cucumber) do |t|
  t.fork = true
  t.cucumber_opts = ['--format', (ENV['CUCUMBER_FORMAT'] || 'progress')]
end

task :cucumber => [:vendor_test_gems]

def run_rails_cucumber_task(version, additional_cucumber_args)
  puts "Testing Rails #{version}"
  if version.empty?
    raise "No Rails version specified - make sure ENV['RAILS_VERSION'] is set, e.g. with `rake cucumber:rails:all`"
  end
  ENV['RAILS_VERSION'] = version
  cmd   = "cucumber --format #{ENV['CUCUMBER_FORMAT'] || 'progress'} #{additional_cucumber_args} features/rails.feature"
  puts "Running command: #{cmd}"
  system(cmd)
end

def define_rails_cucumber_tasks(additional_cucumber_args = '')
  namespace :rails do
    RAILS_VERSIONS.each do |version|
      desc "Test integration of the gem with Rails #{version}"
      task version => [:vendor_test_gems] do
        exit 1 unless run_rails_cucumber_task(version, additional_cucumber_args)
      end
    end

    desc "Test integration of the gem with all Rails versions"
    task :all do
      results = RAILS_VERSIONS.map do |version|
        run_rails_cucumber_task(version, additional_cucumber_args)
      end

      exit 1 unless results.all?
    end
  end
end

namespace :cucumber do
  namespace :wip do
    define_rails_cucumber_tasks('--tags @wip')
  end

  define_rails_cucumber_tasks

  rule /#{"(" + FEATURES.join("|") + ")"}/ do |t|
    framework = t.name
    desc "Test integration of the gem with #{framework}"
    task framework.to_sym do
      puts "Testing #{framework.split(":").last}..."
      cmd = "cucumber --format #{ENV['CUCUMBER_FORMAT'] || 'progress'} features/#{framework.split(":").last}.feature"
      puts "Running command: #{cmd}"
      system(cmd)
    end
  end
end

#############################################################################
#
# Packaging tasks
#
#############################################################################

desc "Create tag v#{version} and build and push #{gem_file} to Rubygems"
task :release => :build do
  unless `git branch` =~ /^\* master$/
    puts "You must be on the master branch to release!"
    exit!
  end
  sh "git commit --allow-empty -a -m 'Release #{version}'"
  sh "git tag v#{version}"
  sh "git push origin master"
  sh "git push origin v#{version}"
  sh "gem push pkg/#{name}-#{version}.gem"
end

desc "Build #{gem_file} into the pkg directory"
task :build => :gemspec do
  sh "mkdir -p pkg"
  sh "gem build #{gemspec_file}"
  sh "mv #{gem_file} pkg"
end

desc "Generate #{gemspec_file}"
task :gemspec => :validate do
  # read spec file and split out manifest section
  spec = File.read(gemspec_file)
  head, manifest, tail = spec.split("  # = MANIFEST =\n")

  # replace name version and date
  replace_header(head, :name)
  replace_header(head, :version)
  replace_header(head, :date)
  #comment this out if your rubyforge_project has a different name
  replace_header(head, :rubyforge_project)

  # determine file list from git ls-files
  files = `git ls-files`.
    split("\n").
    sort.
    reject { |file| file =~ /^\./ }.
    reject { |file| file =~ /^(rdoc|pkg)/ }.
    map { |file| "    #{file}" }.
    join("\n")

  # piece file back together and write
  manifest = "  s.files = %w[\n#{files}\n  ]\n"
  spec = [head, manifest, tail].join("  # = MANIFEST =\n")
  File.open(gemspec_file, 'w') { |io| io.write(spec) }
  puts "Updated #{gemspec_file}"
end

desc "Validate #{gemspec_file}"
task :validate do
  libfiles = Dir['lib/*'] - ["lib/#{name}.rb", "lib/#{name}_tasks.rb", "lib/#{name}", "lib/rails"]
  unless libfiles.empty?
    puts "Directory `lib` should only contain `#{name}.rb` and `#{name}_tasks.rb` files, and `#{name}` and lib/rails dir."
    exit!
  end
  unless Dir['VERSION*'].empty?
    puts "A `VERSION` file at root level violates Gem best practices."
    exit!
  end
end
