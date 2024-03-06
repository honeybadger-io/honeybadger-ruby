require_relative '../rails_helper'

describe 'Rails ActiveJob Adapter Test', if: RAILS_PRESENT, type: :request do
  include ActiveJob::TestHelper if RAILS_PRESENT
  load_rails_hooks(self)

  it 'reports exceptions' do
    Honeybadger.flush do
      perform_enqueued_jobs do
        expect do
          ErrorJob.perform_later({ some: 'data' })
        end.to raise_error(StandardError)
      end
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
    expect(Honeybadger::Backend::Test.notifications[:notices][0].context).to \
      include(
        arguments: [{ some: 'data' }],
        component: :good_job,
        enqueued_at: anything,
        executions: 1,
        job_class: ErrorJob,
        job_id: anything,
        priority: anything,
        queue_name: 'default',
        scheduled_at: anything
      )
  end
end
