class ErrorJob < ActiveJob::Base
  def perform(opts = {})
    raise "exception raised in job"
  end
end
