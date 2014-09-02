require 'honeybadger/plugins/delayed_job'
require 'honeybadger/config'
require 'honeybadger/agent'
require 'honeybadger/trace'

begin
  require 'delayed_job'
  DELAYED_JOB_INSTALLED = true
rescue LoadError
  DELAYED_JOB_INSTALLED = false
  nil
end

describe "DelayedJob integration" do
  if ! DELAYED_JOB_INSTALLED
    context "when it's not installed" do
      let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER) }

      it "doesn't install the plugin" do
        expect(Honeybadger::Plugin.instances[:delayed_job].load!(config)).to eq false
      end
    end
  else
    # Prepend the load path with delayed_job's spec directory so that we can take
    # advantage of their test backend:
    # https://github.com/collectiveidea/delayed_job/blob/master/spec/delayed/backend/test.rb
    $:.unshift(File.join(Gem::Specification.find_by_name('delayed_job').full_gem_path, 'spec'))
    Delayed::Worker.backend = :test

    # Note: This is happening once before the tests run.
    CONFIG = Honeybadger::Config.new(logger: NULL_LOGGER)
    Honeybadger::Plugin.instances[:delayed_job].load!(CONFIG)

    class ExceptionTester
      def null_method
      end

      def will_raise
        raise "raised from will_raise"
      end
    end

    context "when it's installed", order: :defined do
      let(:config) { CONFIG }
      let(:worker) { Delayed::Worker.new }

      after  { Delayed::Job.delete_all }

      context "when a method is delayed" do
        let(:method_name) { :null_method }

        before { ExceptionTester.new.delay.send(method_name) }

        specify { expect(Delayed::Job.count).to eq 1 }

        it "queues a new trace" do
          trace = nil
          expect(Honeybadger::Agent).to receive(:trace).with(kind_of(Honeybadger::Trace))
          worker.work_off
        end

        context "and an exception occurs" do
          let(:method_name) { :will_raise }

          after  { worker.work_off }

          it "notifies Honeybadger" do
            expect(Honeybadger).to receive(:notify_or_ignore).once
          end
        end
      end
    end
  end
end
