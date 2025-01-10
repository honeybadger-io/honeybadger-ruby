require_relative "../rails_helper"
require "honeybadger/notification_subscriber"

class TestSubscriber < Honeybadger::NotificationSubscriber; end

describe "Rails Insights Notification Subscribers", if: RAILS_PRESENT, type: :request do
  load_rails_hooks(self)

  before do
    Honeybadger::Backend::Test.events.clear
  end

  it "records correct durations for concurrent notifications" do
    Honeybadger.config[:"insights.enabled"] = true
    Honeybadger.config[:"events.batch_size"] = 0

    mutex, sequence = Mutex.new, 1
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) do
      if caller_locations.any? { |loc| loc.base_label == "finish" }
        10
      else
        mutex.synchronize { sequence += 1 }
      end
    end

    ActiveSupport::Notifications.subscribe("test.timing", TestSubscriber.new)

    # Create multiple threads that will fire notifications
    threads = 5.times.map do
      Thread.new do
        ActiveSupport::Notifications.instrument("test.timing") do
          sleep(0.1)
        end
      end
    end

    threads.each(&:join)
    sleep(0.2)

    expect(Honeybadger::Backend::Test.events.map { |e| e[:duration] }.uniq.length).to eq(5)
  end

  it "records correct durations with regex subscription" do
    Honeybadger.config[:"insights.enabled"] = true
    Honeybadger.config[:"events.batch_size"] = 0

    sequence = 1
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) do
      if caller_locations.any? { |loc| loc.base_label == "finish" }
        10
      else
        sequence += 1
      end
    end

    # Subscribe to multiple notification types with a regex
    ActiveSupport::Notifications.subscribe(/^test\.(foo|bar|baz)/, TestSubscriber.new)

    # Send different types of notifications sequentially
    %w[test.foo test.bar test.baz].each do |notification_type|
      ActiveSupport::Notifications.instrument(notification_type) do
        sleep(0.1)
      end
    end

    events = Honeybadger::Backend::Test.events
    sleep(0.2)

    expect(events.size).to eq(3)
    expect(events.map { |e| e[:event_type] }.sort).to eq(%w[test.foo test.bar test.baz].sort)
    expect(events.map { |e| e[:duration] }.uniq.size).to eq(3)
  end
end
