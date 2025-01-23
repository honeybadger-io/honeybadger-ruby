require_relative "../rails_helper"

RAILS_ERROR_REPORTER_SUPPORTED = defined?(::ActiveSupport::ErrorReporter)
return unless RAILS_ERROR_REPORTER_SUPPORTED

RAILS_ERROR_SOURCE_SUPPORTED = ::Rails::VERSION::STRING >= "7.1"

describe "Rails error subscriber integration" do
  load_rails_hooks(self)

  it "always reports handled exceptions" do
    Honeybadger.flush do
      Rails.error.handle(severity: :warning, context: {key: "value"}) do
        raise "Oh no"
      end
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
    notice = Honeybadger::Backend::Test.notifications[:notices].first
    expect(notice.error_class).to eq("RuntimeError")
    expect(notice.context).to eq({key: "value"})
    tags = ["severity:warning", "handled:true"]
    tags << "source:application" if RAILS_ERROR_SOURCE_SUPPORTED
    expect(notice.tags).to eq(tags)
  end

  it "ignores unhandled exceptions on Rails" do
    expect do
      Honeybadger.flush do
        Rails.application.executor.wrap do
          Rails.error.set_context(key: "value")
          raise "Oh no"
        end
      end
    end.to raise_error(RuntimeError, "Oh no")

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(0)
  end

  it "ignores active_support exceptions on Rails 7.1+ (source supported)", if: RAILS_ERROR_SOURCE_SUPPORTED do
    expect do
      Honeybadger.flush do
        Rails.application.executor.wrap do
          Rails.error.set_context(key: "value")
          raise "Oh no"
        end
      end
    end.to raise_error(RuntimeError, "Oh no")

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(0)
  end

  it "reports exceptions with source", if: RAILS_ERROR_SOURCE_SUPPORTED do
    Honeybadger.flush do
      Rails.error.handle(severity: :warning, context: {key: "value"}, source: "task") do
        raise "Oh no"
      end
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
    notice = Honeybadger::Backend::Test.notifications[:notices].first
    expect(notice.error_class).to eq("RuntimeError")
    expect(notice.context).to eq({key: "value"})
    expect(notice.tags).to eq(["severity:warning", "handled:true", "source:task"])
  end

  it "doesn't report errors from ignored sources", if: RAILS_ERROR_SOURCE_SUPPORTED do
    Honeybadger.configure do |config|
      config.rails.subscriber_ignore_sources += [/ignored/]
    end

    Honeybadger.flush do
      Rails.error.handle(severity: :warning, context: {key: "value"}, source: "ignored_source") do
        raise "Oh no"
      end
    end

    expect(Honeybadger::Backend::Test.notifications[:notices]).to be_empty
  end
end
