require 'honeybadger/plugins/breadcrumbs'
require 'honeybadger/config'

describe "Breadcrumbs Plugin" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }
  let(:active_support) { double("ActiveSupport::Notifications") }

  before do
    Honeybadger::Plugin.instances[:breadcrumbs].reset!
    stub_const("ActiveSupport::Notifications", active_support)
  end

  describe Honeybadger::Plugins::RailsBreadcrumbs do
    describe ".subscribe_to_notification" do
      let(:name) { "a.notification" }
      let(:config) {{ foo: "bar" }}
      let(:data) {{a: :b}}

      it "registers with activesupport and delgates to send_breadcrumb_notification" do
        expect(described_class).to receive(:send_breadcrumb_notification).with(name, 10, config, data)
        expect(active_support).to receive(:subscribe).with(name) do |&block|
          block.call("noop", 10, 20, "noop", data)
        end

        described_class.subscribe_to_notification(name, config)
      end

      it "reports nil duration if finish time is nil" do
        expect(described_class).to receive(:send_breadcrumb_notification).with(name, nil, config, data)
        expect(active_support).to receive(:subscribe).with(name) do |&block|
          block.call("noop", 100, nil, "noop", data)
        end

        described_class.subscribe_to_notification(name, config)
      end
    end

    describe ".send_breadcrumb_notification" do
      it "adds a breadcrumb with overridden config settings" do
        data = {cars: "trucks"}
        config = {message: "config message", category: :test}

        expect(Honeybadger).to receive(:add_breadcrumb).with("config message", {category: :test, metadata: data.merge({duration: 99})})
        described_class.send_breadcrumb_notification("message", 99, config, data)
      end

      it "adds a breadcrumb with defaults" do
        expect(Honeybadger).to receive(:add_breadcrumb).with("message", {category: :custom, metadata: {duration: 100}})
        described_class.send_breadcrumb_notification("message", 100, config, {})
      end

      it "ignores nil duration" do
        expect(Honeybadger).to receive(:add_breadcrumb).with("message", {category: :custom, metadata: {}})
        described_class.send_breadcrumb_notification("message", nil, config, {})
      end

      describe ":message" do
        it "can allow a string" do
          config = { message: "config message" }
          expect(Honeybadger).to receive(:add_breadcrumb).with("config message", anything)
          described_class.send_breadcrumb_notification("noop", 100, config, {})
        end

        it "allows for a proc" do
          data = {}
          config = {
            message: lambda do |d|
              expect(d).to eq(data)
              "a dynamic message"
            end
          }

          expect(Honeybadger).to receive(:add_breadcrumb).with("a dynamic message", anything)
          described_class.send_breadcrumb_notification("noop", 100, config, data)
        end

        it "defaults to instrumentation name if not set" do
          expect(Honeybadger).to receive(:add_breadcrumb).with("instrument name", anything)
          described_class.send_breadcrumb_notification("instrument name", 100, {}, {})
        end
      end

      describe ":exclude_when" do
        it "excludes events if proc returns true" do
          data = {}
          config = {
            exclude_when: lambda do |d|
              expect(d).to eq(data)
              true
            end
          }

          expect(Honeybadger).to_not receive(:add_breadcrumb)
          described_class.send_breadcrumb_notification("name", 10, config, data)
        end

        it "includes event if proc returns true" do
          config = { exclude_when: ->(_){ false } }
          expect(Honeybadger).to receive(:add_breadcrumb)
          described_class.send_breadcrumb_notification("name", 33, config, {})
        end
      end

      # Skip this spec during Apprasal runs that don't have ActiveSupport loaded
      describe ":select_keys", skip: !Hash.method_defined?(:slice) do
        it "can filter metadata" do
          data = {a: :b, c: :d}
          removed_data = {c: :d}
          config = { select_keys: [:a] }

          expect(Honeybadger).to receive(:add_breadcrumb).with(anything, hash_including(metadata: hash_not_including(removed_data)))
          described_class.send_breadcrumb_notification("_", 0, config, data)
        end
      end

      describe ":transform" do
        it "transforms data payload" do
          data     = {old: "data"}
          new_data = {new: "data"}
          config = {
            transform: lambda do |d|
              expect(d).to eq(data)
              new_data
            end
          }
          expect(Honeybadger).to receive(:add_breadcrumb).with(anything, hash_including(metadata: new_data))

          described_class.send_breadcrumb_notification("name", 33, config, data)
        end
      end

    end
  end
end
