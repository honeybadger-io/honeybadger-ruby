require 'rubygems'
require 'bundler/setup'
require 'honeybadger/version'

module Release
  CHANGELOG_FILE    = 'CHANGELOG.md'.freeze
  CHANGELOG_HEADING = '## [Unreleased]'
  EXIT_CMD          = 'bundle update honeybadger && git add -p'
  VERSION_FILE      = 'lib/honeybadger/version.rb'

  def self.bump_changelog(version = nil)
    version = next_version(Honeybadger::VERSION) unless version.to_s =~ /\S/
    contents = File.read(CHANGELOG_FILE)
    unless contents =~ Regexp.new(Regexp.escape("## [#{version}]"))
      File.write(CHANGELOG_FILE, contents.gsub(CHANGELOG_HEADING, "#{CHANGELOG_HEADING}\n\n## [#{version}] - #{Time.now.strftime("%Y-%m-%d")}"))
    end
  end

  def self.bump
    version = next_version(Honeybadger::VERSION)

    # Update the version file.
    File.write(VERSION_FILE, File.read(VERSION_FILE).gsub(Honeybadger::VERSION, version))

    # Update the changelog.
    bump_changelog(version)

    unless Bundler.with_clean_env { system(EXIT_CMD) }
      puts "Failed to bump release version."
      exit!
    end
  end

  def self.next_version(version, offset = 1)
    offset = -1 * offset
    segments = Gem::Version.new(version).segments.dup
    segments.pop while segments.any? { |s| String === s }
    segments[offset] = segments[offset].succ
    segments.join('.')
  end
end
