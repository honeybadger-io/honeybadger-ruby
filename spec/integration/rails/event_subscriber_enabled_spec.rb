require_relative "../rails_helper"

return unless RAILS_PRESENT && defined?(Rails.event)

Honeybadger.configure do |config|
  config.rails.insights.structured_events = true
  config.backend = "test"
  config.events.batch_size = 0
end

RSpec.describe "Rails Insights Event Subscriber" do
  it "captures Rails.event events" do
    Honeybadger.flush do
      Rails.event.notify("test.rails_event", {rails_key: "rails_value"})
    end

    rails_events = Honeybadger::Backend::Test.events.select { |e| e[:event_type] == "test.rails_event" }
    expect(rails_events).not_to be_empty
    expect(rails_events.first[:payload][:rails_key]).to eq("rails_value")
    expect(rails_events.first[:name]).to be_blank
  end
end
