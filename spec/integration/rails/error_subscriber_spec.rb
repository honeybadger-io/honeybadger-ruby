require_relative '../rails_helper'

RAILS_ERROR_SOURCE_SUPPORTED = defined?(::Rails::VERSION) && ::Rails::VERSION::STRING >= '7.1'

describe "Rails error subscriber integration", if: defined?(::ActiveSupport::ErrorReporter) do
  load_rails_hooks(self)

  it "reports exceptions" do
    Rails.error.handle(severity: :warning, context: {key: 'value'}, source: "task") do
      raise RuntimeError, "Oh no"
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
    notice = Honeybadger::Backend::Test.notifications[:notices].first
    expect(notice.error_class).to eq("RuntimeError")
    expect(notice.context).to eq({key: 'value'})
    tags = ["reporter:rails.error_subscriber", "severity:warning", "handled:true"]
    tags << "source:task" if RAILS_ERROR_SOURCE_SUPPORTED
    expect(notice.tags).to eq(tags)
  end

  it "doesn't report ignored sources", if: RAILS_ERROR_SOURCE_SUPPORTED do
    Honeybadger.configure do |config|
      config[:'rails.subscriber_ignore_sources'] += [/ignored/]
    end

    Rails.error.handle(severity: :warning, context: {key: 'value'}, source: "ignored_source") do
      raise RuntimeError, "Oh no"
    end

    expect(Honeybadger::Backend::Test.notifications[:notices]).to be_empty
  end
end
