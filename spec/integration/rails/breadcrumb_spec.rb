require_relative "../rails_helper"

return unless RAILS_PRESENT

Honeybadger.configure do |config|
  config.breadcrumbs.enabled = true
  config.backend = "test"
end

describe "Rails Breadcrumbs integration", type: :request do
  unless SKIP_ACTIVE_RECORD
    around(:example) do |example|
      ActiveRecord::Base.connection.execute("CREATE TABLE things (name char(200));")
      example.run
      ActiveRecord::Base.connection.execute("DROP TABLE things;")
    end
  end

  RSpec::Matchers.define :contain_breadcrumb_including do |expected|
    match do |actual|
      get_trail(actual).any? do |breadcrumb|
        include(expected).matches?(breadcrumb.to_h)
      end
    end

    failure_message do |actual|
      "expected a trail from:\n\n #{JSON.pretty_generate(actual.breadcrumbs.to_h)}\n\nto contain:\n\n#{JSON.pretty_generate(expected)}"
    end
  end

  def notices
    Honeybadger::Backend::Test.notifications[:notices]
  end

  def get_trail(notice)
    notice.as_json[:breadcrumbs][:trail]
  end

  it "creates log event" do
    Honeybadger.flush { get "/breadcrumbs/log_breadcrumb_event" }
    expect(notices.first).to contain_breadcrumb_including({
      category: "log",
      message: "test log event",
      metadata: include({severity: "INFO"})
    })
  end

  it "creates active_record event", skip: SKIP_ACTIVE_RECORD do
    Honeybadger.flush { get "/breadcrumbs/active_record_event" }
    expect(notices.first).to contain_breadcrumb_including({
      category: "query",
      message: /Active Record - .*/,
      metadata: include({
        sql: /INSERT INTO "things" \("name"\) VALUES \(\?\)/
      })
    })
  end

  it "creates active_job event" do
    Honeybadger.flush { get "/breadcrumbs/active_job_event" }
    expect(notices.first).to contain_breadcrumb_including({
      category: "job",
      message: "Active Job Enqueue"
    })
  end

  it "creates cache event" do
    Honeybadger.flush { get "/breadcrumbs/cache_event" }
    expect(notices.first).to contain_breadcrumb_including({
      category: "query",
      message: "Active Support Cache Read"
    })
  end
end
