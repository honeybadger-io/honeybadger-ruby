require 'spec_helper'
require 'honeybadger/monitor'

begin
  require 'delayed_job'
  require 'honeybadger/integrations/delayed_job/plugin'
  DELAYED_JOB_INSTALLED = true
rescue LoadError
  DELAYED_JOB_INSTALLED = false
  nil
end

if DELAYED_JOB_INSTALLED
  # Prepend the load path with delayed_job's spec directory so that we can take
  # advantage of their test backend:
  # https://github.com/collectiveidea/delayed_job/blob/master/spec/delayed/backend/test.rb
  $:.unshift(File.join(Gem::Specification.find_by_name('delayed_job').full_gem_path, 'spec'))
  Delayed::Worker.backend = :test

  class ExceptionTester
    def null_method
    end

    def will_raise
      raise "raised from will_raise"
    end
  end

  describe "DelayedJob integration" do
    let(:worker) { @worker }

    before(:all) do
      Delayed::Worker.plugins = [Honeybadger::Integrations::DelayedJob::Plugin]
      @worker = Delayed::Worker.new
    end

    after { Delayed::Job.delete_all }

    context "when a method is delayed" do
      let(:method_name) { :null_method }

      before { ExceptionTester.new.delay.send(method_name) }

      specify { expect(Delayed::Job.count).to eq 1 }

      it "queues a new trace" do
        trace_id = nil
        Honeybadger::Monitor.worker.should_receive(:queue_trace).once.and_return do
          # This ensures that Honeybadger::Monitor.worker.trace is not nil when
          # it's queued from the worker. There may still be an edge case where
          # that's possible. (see #84)
          trace_id = Thread.current[:hb_trace_id]
        end
        worker.work_off
        expect(trace_id).not_to be_nil
      end

      context "and an exception occurs" do
        let(:method_name) { :will_raise }

        after  { worker.work_off }

        it "notifies Honeybadger" do
          Honeybadger.should_receive(:notify_or_ignore).once
        end
      end

      context "and a threshold is set" do
        let(:method_name) { :will_raise }

        before { ::Honeybadger.configuration.delayed_job_attempt_threshold = 2 }
        after { ::Honeybadger.configuration.delayed_job_attempt_threshold = 0 }

        it "does not notify Honeybadger on first occurence" do
          Honeybadger.should_not_receive(:notify_or_ignore)

          worker.work_off
        end
      end
    end
  end
end
