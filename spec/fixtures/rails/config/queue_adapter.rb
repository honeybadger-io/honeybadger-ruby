class ErrorJob < ActiveJob::Base
  def perform
    pp "PERFORM #{::Rails.application.config.active_job}", caller
    raise "exception raised in job"
  end
end

class ErrorJobController < ApplicationController
  def enqueue_error_job
    ErrorJob.perform_later
    head 200
  end
end

Rails.application.routes.append do
  post "/enqueue_error_job", to: "error_job#enqueue_error_job"
end

