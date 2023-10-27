class ErrorJob < ActiveJob::Base
  around_perform :around_for_testing

  def perform(opts={})
    raise "exception raised in job"
  end

  def around_for_testing(*args)
    yield
  end
end

class ErrorJobController < ApplicationController
  def enqueue_error_job
    ErrorJob.perform_later({some: "data"})
    head 200
  end
end

Rails.application.routes.append do
  post "/enqueue_error_job", to: "error_job#enqueue_error_job"
end

