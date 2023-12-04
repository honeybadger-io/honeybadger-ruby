require_relative '../rails_helper'

describe "Rails Async Queue Adapter Test", if: RAILS_PRESENT, type: :request do
  include ActiveJob::TestHelper if RAILS_PRESENT
  load_rails_hooks(self)

  it "reports exceptions" do
    Honeybadger.flush do
      perform_enqueued_jobs do
        expect {
          ErrorJob.perform_later({some: 'data'})
        }.to raise_error(StandardError)
      end
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
    expect(Honeybadger::Backend::Test.notifications[:notices][0].params[:job_arguments][0]).to eq({some: 'data'})
  end

end
