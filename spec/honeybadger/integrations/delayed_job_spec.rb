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

    before do
      Honeybadger::Dependency.inject!
      ExceptionTester.new.delay.will_raise
    end

    after { Delayed::Job.delete_all }

    specify { expect(Delayed::Job.count).to eq 1 }

    it "is notified when an exception occurs in a delayed job" do
      Honeybadger.should_receive(:notify_or_ignore).once
      worker.work_off
    end
  end
end
