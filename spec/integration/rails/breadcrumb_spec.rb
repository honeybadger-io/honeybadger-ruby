require_relative '../rails_helper'

describe 'Rails Breadcrumbs integration', if: RAILS_PRESENT, type: :request do
  load_rails_hooks(self)

  around(:example) do |example|
    ActiveRecord::Base.connection.execute("CREATE TABLE things (name char(200));")
    example.run
    ActiveRecord::Base.connection.execute("DROP TABLE things;")
  end

  RSpec::Matchers.define :contain_breadcrumb_including do |expected|
    match do |actual|
      get_trail(actual).any? do |breadcrumb|
        include(expected).matches?(breadcrumb.to_h)
      end
    end
  end

  def notices
    Honeybadger::Backend::Test.notifications[:notices]
  end

  def get_trail(notice)
    notice.as_json[:breadcrumbs][:trail]
  end

  def puts_breadcrumbs(notice)
    puts JSON.pretty_generate(get_trail(notice))
  end

  it "creates log event" do
    get "/breadcrumbs/log_breadcrumb_event"
    expect(notices.first).to contain_breadcrumb_including({
      category: "log",
      message: "test log event",
      metadata: include({ severity: "INFO" })
    })
  end

  it "creates active_record event" do
    get "/breadcrumbs/active_record_event"
    expect(notices.first).to contain_breadcrumb_including({
      category: "query",
      message: "Active Record SQL",
      metadata: include({
        sql: "INSERT INTO \"things\" (\"name\") VALUES (?)"
      })
    })
  end

  it "creates active_job event" do
    get "/breadcrumbs/active_job_event"
    expect(notices.first).to contain_breadcrumb_including({
      category: "job",
      message: "Active Job Enqueue"
    })
  end

  it "creates cache event" do
    get "/breadcrumbs/cache_event"
    expect(notices.first).to contain_breadcrumb_including({
      category: "query",
      message: "Active Support Cache Read"
    })
  end
end
