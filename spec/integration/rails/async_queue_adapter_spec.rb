require_relative '../rails_helper'

describe "Rails Async Queue Adapter Test", if: RAILS_PRESENT, type: :request do
  load_rails_hooks(self)

  it "reports exceptions" do
    #include ActiveJob::TestHelper
    
    Honeybadger.flush do
      post "/enqueue_error_job"
      expect(response.status).to eq(200)
    end

    # expect { perform_enqueued_jobs }.to raise_error(RuntimeError)

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
  end

end
