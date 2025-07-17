require "rubygems"
require "bundler/setup"
require "honeybadger/version"

module Release
  CHANGELOG_FILE = "CHANGELOG.md".freeze
  CHANGELOG_HEADING = "## [Unreleased]"
  EXIT_CMD = "bundle update honeybadger && git add -p"

  def self.run_before(version)
    bump_changelog(version)
  end

  def self.run_after(version)
    Bundler.with_unbundled_env { system(EXIT_CMD) }
  end

  def self.bump_changelog(version)
    contents = File.read(CHANGELOG_FILE)
    if contents&.match?(Regexp.new(Regexp.escape("## [#{version}]")))
      puts "ERROR: #{version} already exists in CHANGELOG.md"
      exit 1
    end

    File.write(CHANGELOG_FILE, contents.gsub(CHANGELOG_HEADING, "#{CHANGELOG_HEADING}\n\n## [#{version}] - #{Time.now.strftime("%Y-%m-%d")}"))
  end
end
