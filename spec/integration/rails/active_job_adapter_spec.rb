require_relative "../rails_helper"

return unless RAILS_PRESENT

Honeybadger.configure do |config|
  config.backend = "test"
end

RSpec.describe "Rails ActiveJob Adapter Test", type: :request do
  include ActiveJob::TestHelper

  it "reports exceptions" do
    Honeybadger.flush do
      perform_enqueued_jobs do
        expect do
          ErrorJob.perform_later({some: "data"})
        end.to raise_error(StandardError)
      end
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
    expect(Honeybadger::Backend::Test.notifications[:notices][0].params[:arguments][0]).to eq({some: "data"})
    expect(Honeybadger::Backend::Test.notifications[:notices][0].context).to \
      include(
        component: ErrorJob,
        action: "perform",
        enqueued_at: anything,
        executions: 1,
        job_class: ErrorJob,
        job_id: anything,
        priority: anything,
        queue_name: "default",
        scheduled_at: anything
      )
  end

  it "does not report exceptions if the attempt threshold is not reached" do
    Honeybadger.config[:"active_job.attempt_threshold"] = 2

    Honeybadger.flush do
      perform_enqueued_jobs do
        expect do
          ErrorJob.perform_later({some: "data"})
        end.to raise_error(StandardError)
      end
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(0)

    Honeybadger.config[:"active_job.attempt_threshold"] = 0
  end
end
