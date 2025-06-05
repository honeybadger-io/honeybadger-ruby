require "honeybadger/config"
require "honeybadger/agent"

class ExceptionTester
  def null_method
  end

  def will_raise
    raise "raised from will_raise"
  end
end

begin
  require "delayed_job"
  require "honeybadger/plugins/delayed_job/plugin"

  describe "DelayedJob integration" do
    # Prepend the load path with delayed_job's spec directory so that we can take
    # advantage of their test backend:
    # https://github.com/collectiveidea/delayed_job/blob/master/spec/delayed/backend/test.rb
    $:.unshift(File.join(Gem::Specification.find_by_name("delayed_job").full_gem_path, "spec"))
    Delayed::Worker.backend = :test

    let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }
    let(:worker) { @worker }

    before(:all) do
      Delayed::Worker.plugins = [Honeybadger::Plugins::DelayedJob::Plugin]
      @worker = Delayed::Worker.new
    end

    after { Delayed::Job.delete_all }

    context "when a method is delayed" do
      let(:method_name) { :null_method }

      before { ExceptionTester.new.delay.send(method_name) }

      specify { expect(Delayed::Job.count).to eq 1 }

      context "and an exception occurs" do
        let(:method_name) { :will_raise }

        after { worker.work_off }

        it "notifies Honeybadger" do
          expect(Honeybadger).to receive(:notify)
        end
      end

      context "and a threshold is set" do
        let(:method_name) { :will_raise }

        before { ::Honeybadger.config[:"delayed_job.attempt_threshold"] = 2 }
        after { ::Honeybadger.config[:"delayed_job.attempt_threshold"] = 0 }

        it "does not notify Honeybadger on first occurence" do
          expect(Honeybadger).not_to receive(:notify)
          worker.work_off
        end
      end
    end
  end
rescue LoadError
  nil
end
