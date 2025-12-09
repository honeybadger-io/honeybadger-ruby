require_relative "../rails_helper"
require "honeybadger/notification_subscriber"

class TestSubscriber < Honeybadger::NotificationSubscriber; end

describe "Rails Insights Notification Subscribers", if: RAILS_PRESENT do
  load_rails_hooks(self)

  it "records correct durations for concurrent notifications" do
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
    # Wait for all events to be processed
    sleep(0.2)

    test_timing_events = Honeybadger::Backend::Test.events.select { |e| e[:event_type] == "test.timing" }
    expect(test_timing_events.map { |e| e[:duration] }.uniq.length).to eq(5)
  end
end
