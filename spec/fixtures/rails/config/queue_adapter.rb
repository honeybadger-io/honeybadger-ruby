class ErrorJob < ActiveJob::Base
  around_perform :around_for_testing

  def perform(opts={})
    raise "exception raised in job"
  end

  def around_for_testing(*args)
    yield
  end
end


