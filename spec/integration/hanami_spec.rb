begin
  require "hanami"
  require "rack/test"
  HANAMI_PRESENT = true
rescue LoadError
  HANAMI_PRESENT = false
  puts "Skipping Hanami integration specs."
end

return unless HANAMI_PRESENT

require FIXTURES_PATH.join("hanami", "app.rb")
require "honeybadger/init/hanami"

RSpec.describe "Hanami integration" do
  include Rack::Test::Methods

  def app
    Hanami.app
  end

  before(:each) do
    Honeybadger.configure do |config|
      config.api_key = "gem testing"
      config.backend = "test"
    end
  end

  after(:each) do
    Honeybadger::Backend::Test.notifications[:notices].clear
  end

  it "reports exceptions" do
    error_message = "exception raised from test Hanami app in honeybadger gem test suite"
    Honeybadger.flush do
      expect { get "/runtime_error" }.to raise_error(error_message)
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
    notice = Honeybadger::Backend::Test.notifications[:notices][0]
    expect(notice.error_message).to match(error_message)
  end
end
