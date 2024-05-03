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
    expect(Honeybadger::Backend::Test.notifications[:notices][0].params[:arguments][0]).to eq({ some: 'data' })
    expect(Honeybadger::Backend::Test.notifications[:notices][0].context).to \
      include(
        component: 'active_job',
        action: 'perform',
        enqueued_at: anything,
        executions: 1,
        job_class: ErrorJob,
        job_id: anything,
        priority: anything,
        queue_name: 'default',
        scheduled_at: anything
      )
  end

  it 'does not report exceptions if the attempt threshold is not reached', focus: true do
    Honeybadger.config[:'active_job.attempt_threshold'] = 2

    Honeybadger.flush do
      perform_enqueued_jobs do
        expect do
          ErrorJob.perform_later({ some: 'data' })
        end.to raise_error(StandardError)
      end
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(0)

    Honeybadger.config[:'active_job.attempt_threshold'] = 0
  end
end
