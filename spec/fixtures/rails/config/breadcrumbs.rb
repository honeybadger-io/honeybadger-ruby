class Thing < ActiveRecord::Base; end

class Job < ActiveJob::Base
  def perform
    # Doing something here
  end
end

class BreadcrumbController < ApplicationController
  def active_record_event
    Thing.create(name: "a thing")
    sync_notice
  end

  def log_breadcrumb_event
    Rails.logger.info("test log event")
    sync_notice
  end

  def active_job_event
    Job.perform_later
    sync_notice
  end

  def cache_event
    Rails.cache.read("test read")
    sync_notice
  end

  private

  def sync_notice
    Honeybadger.notify(StandardError.new('test backend'), sync: true)
  end
end

Rails.application.routes.append do
  BreadcrumbController.action_methods.each do |action|
    get "/breadcrumbs/#{action}", to: "breadcrumb##{action}"
  end
end

