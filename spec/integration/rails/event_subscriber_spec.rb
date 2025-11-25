require_relative "../rails_helper"

describe "Rails Insights Event Subscriber", if: RAILS_PRESENT, type: :request do
  load_rails_hooks(self)

  before do
    Honeybadger.config[:"insights.enabled"] = true
    Honeybadger.config[:"events.batch_size"] = 0

    Honeybadger::Backend::Test.events.clear
  end

  it "subscribes to Rails.event when available", if: defined?(Rails.event) do
    Rails.event.notify("test.rails_event", {rails_key: "rails_value"})

    sleep(0.1)

    rails_events = Honeybadger::Backend::Test.events.select { |e| e[:event_type] == "test.rails_event" }
    expect(rails_events).not_to be_empty
    expect(rails_events.first[:payload][:rails_key]).to eq("rails_value")
    expect(rails_events.first[:name]).to be_blank
  end

  it "does not capture Rails.event events when structured_events is disabled", if: defined?(Rails.event) do
    Honeybadger.config[:"rails.insights.structured_events"] = false

    # Reload the plugin to apply the new config
    Honeybadger::Plugin.instances[:rails].load!(Honeybadger.config)

    Rails.event.notify("test.disabled_event", {rails_key: "rails_value"})

    sleep(0.1)

    rails_events = Honeybadger::Backend::Test.events.select { |e| e[:event_type] == "test.disabled_event" }
    expect(rails_events).to be_empty
  end

  it "gracefully handles Rails.event when not available", unless: defined?(Rails.event) do
    expect { Honeybadger::Plugin.instances[:rails].load!(Honeybadger.config) }.not_to raise_error
  end
end
