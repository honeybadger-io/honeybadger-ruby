class CIHelpers
  def self.results_name
    [
      ENV['TEST_OUTPUT_NAME'],
      gemfile,
    ].compact.join(" - ")
  end

  def self.gemfile
    return nil if ENV['BUNDLE_GEMFILE'].nil?

    ENV['BUNDLE_GEMFILE'].split(/\//).last
  end
end
