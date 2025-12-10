require_relative "../rails_helper"

describe "Rails Insights Event Subscriber", if: (RAILS_PRESENT && defined?(Rails.event)) do
  load_rails_hooks(self)

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
