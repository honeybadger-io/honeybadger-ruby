class Thing < ActiveRecord::Base; end unless SKIP_ACTIVE_RECORD

class Job < ActiveJob::Base
  def perform
    # Doing something here
  end
end

class BreadcrumbController < ApplicationController
  def active_record_event
    ActiveRecord::Base.connection.execute("SELECT '\x83ݔj'")
    Thing.create(name: "a thing")
    notice
  end

  def log_breadcrumb_event
    Rails.logger.info("test log event")
    notice
  end

  def active_job_event
    Job.perform_later
    notice
  end

  def cache_event
    Rails.cache.read("test read")
    notice
  end

  private

  def notice
    Honeybadger.notify(StandardError.new("test backend"))
    head 200
  end
end

Rails.application.routes.append do
  BreadcrumbController.action_methods.each do |action|
    get "/breadcrumbs/#{action}", to: "breadcrumb##{action}"
  end
end
