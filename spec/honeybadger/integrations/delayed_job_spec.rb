require 'spec_helper'
require 'honeybadger/monitor'

begin
  require 'delayed_job'
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
    def will_raise
      raise "raised from will_raise"
    end
  end

  describe "DelayedJob integration" do
    let(:worker) { Delayed::Worker.new }

    before { Honeybadger::Dependency.inject! }
    after { Delayed::Job.delete_all }

    context "when an exception occurs in a delayed method" do
      before { ExceptionTester.new.delay.will_raise }
      after  { worker.work_off }

      specify { expect(Delayed::Job.count).to eq 1 }

      it "notifies Honeybadger" do
        Honeybadger.should_receive(:notify_or_ignore).once
      end
    end
  end
end
