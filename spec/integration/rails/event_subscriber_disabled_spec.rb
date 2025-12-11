require_relative "../rails_helper"

return unless RAILS_PRESENT && defined?(Rails.event)

Honeybadger.configure do |config|
  config.backend = "test"
  config.events.batch_size = 0
end

RSpec.describe "Rails Insights Event Subscriber (disabled)" do
  it "does not capture Rails.event events" do
    expect {
      Honeybadger.flush do
        Rails.event.notify("test.rails_event", {rails_key: "rails_value"})
      end
    }.not_to change(Honeybadger::Backend::Test.events, :count)
  end
end
