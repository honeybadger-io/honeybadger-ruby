require_relative "../rails_helper"

describe "Rails Insights Event Subscriber", if: (RAILS_PRESENT && defined?(Rails.event)) do
  load_rails_hooks(self)

  it "captures Rails.event events" do
    Honeybadger.flush do
      Rails.event.set_context(user_agent: "TestAgent")
      Rails.event.set_context(job_id: "abc123")
      Rails.event.tagged("graphql") do
        Rails.event.tagged(section: "admin") do
          Rails.event.notify("test.rails_event", {rails_key: "rails value"})
        end
      end
    end

    rails_events = Honeybadger::Backend::Test.events.select { |e| e[:event_type] == "test.rails_event" }
    expect(rails_events).not_to be_empty
    expect(rails_events.first[:graphql]).to eq(true)
    expect(rails_events.first[:section]).to eq("admin")
    expect(rails_events.first[:user_agent]).to eq("TestAgent")
    expect(rails_events.first[:job_id]).to eq("abc123")
    expect(rails_events.first[:rails_key]).to eq("rails value")

    expect(rails_events.first[:name]).to be_blank
  end

  it "flattens tags -> context -> payload" do
    Honeybadger.flush do
      Rails.event.set_context(context_key: "context value")
      Rails.event.tagged(tag_key: "tag value", context_key: "tag context value") do
        Rails.event.notify("test.rails_event", {rails_key: "rails value", tag_key: "rails tag value"})
      end
    end

    rails_events = Honeybadger::Backend::Test.events.select { |e| e[:event_type] == "test.rails_event" }
    expect(rails_events).not_to be_empty
    expect(rails_events.first[:context_key]).to eq("context value")
    expect(rails_events.first[:tag_key]).to eq("rails tag value")
    expect(rails_events.first[:rails_key]).to eq("rails value")
  end
end
