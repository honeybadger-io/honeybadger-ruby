require "honeybadger/plugins/solid_queue"
require "honeybadger/config"

describe "SolidQueue Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "solid_queue.insights.enabled": true) }

  before do
    Honeybadger::Plugin.instances[:solid_queue].reset!
  end

  context "when solid_queue is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:solid_queue].load!(config) }.not_to raise_error
    end

    it "does not load the plugin" do
      Honeybadger::Plugin.instances[:solid_queue].load!(config)
      expect(Honeybadger::Plugin.instances[:solid_queue].loaded?).to be(false)
    end
  end

  context "when solid_queue is installed" do
    let(:solid_queue_shim) { Module.new }

    before do
      Object.const_set(:SolidQueue, solid_queue_shim)
    end

    after { Object.send(:remove_const, :SolidQueue) }

    context "when ActiveRecord is not installed" do
      it "does not load the plugin" do
        Honeybadger::Plugin.instances[:solid_queue].load!(config)
        expect(Honeybadger::Plugin.instances[:solid_queue].loaded?).to be(false)
      end
    end

    context "when ActiveRecord is installed" do
      let(:ar_connected) { true }
      let(:active_record_base) do
        connected = ar_connected
        Class.new.tap { |c| c.define_singleton_method(:connected?) { connected } }
      end
      let(:active_record_shim) do
        base = active_record_base
        Module.new.tap { |m| m.const_set(:Base, base) }
      end

      before do
        Object.const_set(:ActiveRecord, active_record_shim)
      end

      after { Object.send(:remove_const, :ActiveRecord) }

      context "when insights are disabled" do
        let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": false) }

        it "does not load the plugin" do
          Honeybadger::Plugin.instances[:solid_queue].load!(config)
          expect(Honeybadger::Plugin.instances[:solid_queue].loaded?).to be(false)
        end
      end

      context "when insights are enabled" do
        it "loads the plugin" do
          Honeybadger::Plugin.instances[:solid_queue].load!(config)
          expect(Honeybadger::Plugin.instances[:solid_queue].loaded?).to be(true)
        end

        context "when ActiveRecord is not yet connected" do
          let(:ar_connected) { false }

          it "still loads the plugin" do
            Honeybadger::Plugin.instances[:solid_queue].load!(config)
            expect(Honeybadger::Plugin.instances[:solid_queue].loaded?).to be(true)
          end
        end
      end

      describe "collectors" do
        let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, "insights.enabled": true, "solid_queue.insights.enabled": true, "solid_queue.insights.cluster_collection": true) }

        let(:supervisor) { true }
        let(:claimed_execution) { double("ClaimedExecution", count: 1) }
        let(:blocked_execution) { double("BlockedExecution", count: 2) }
        let(:failed_execution) { double("FailedExecution", count: 3) }
        let(:scheduled_execution) { double("ScheduledExecution", count: 4) }
        let(:finished_jobs) { double("finished_jobs", count: 5) }
        let(:where_chain) { double("where_chain", not: finished_jobs) }
        let(:job) { double("Job") }
        let(:process) { double("Process") }
        let(:queue) { double("Queue", name: "default", size: 10, latency: 42) }

        before do
          supervisor_result = supervisor
          ::SolidQueue.define_singleton_method(:supervisor?) { supervisor_result }

          ::SolidQueue.const_set(:ClaimedExecution, claimed_execution)
          ::SolidQueue.const_set(:BlockedExecution, blocked_execution)
          ::SolidQueue.const_set(:FailedExecution, failed_execution)
          ::SolidQueue.const_set(:ScheduledExecution, scheduled_execution)
          ::SolidQueue.const_set(:Job, job)
          ::SolidQueue.const_set(:Process, process)
          ::SolidQueue.const_set(:Queue, queue.class)

          allow(job).to receive(:where).and_return(where_chain)
          allow(process).to receive(:where).with(kind: "Worker").and_return(double(count: 6))
          allow(process).to receive(:where).with(kind: "Dispatcher").and_return(double(count: 7))
          allow(::SolidQueue::Queue).to receive(:all).and_return([queue])
        end

        it "can execute collectors" do
          expect {
            Honeybadger::Plugin.instances[:solid_queue].collectors.each do |options, collect_block|
              Honeybadger::Plugin::CollectorExecution.new("solid_queue", config, options, &collect_block).call
            end
          }.not_to raise_error
        end

        it "collects solid_queue stats" do
          expect(::SolidQueue::ClaimedExecution).to receive(:count)
          expect(::SolidQueue::BlockedExecution).to receive(:count)
          expect(::SolidQueue::FailedExecution).to receive(:count)
          expect(::SolidQueue::ScheduledExecution).to receive(:count)
          expect(::SolidQueue::Job).to receive(:where).with(no_args).and_return(where_chain)
          expect(where_chain).to receive(:not).with(finished_at: nil).and_return(finished_jobs)
          expect(::SolidQueue::Queue).to receive(:all).and_return([queue])
          expect(queue).to receive(:size).and_return(10)
          expect(queue).to receive(:latency).and_return(42)

          Honeybadger::Plugin.instances[:solid_queue].collectors.each do |options, collect_block|
            Honeybadger::Plugin::CollectorExecution.new("solid_queue", config, options, &collect_block).call
          end
        end

        context "when ActiveRecord is not connected" do
          let(:ar_connected) { false }

          it "does not query the database" do
            expect(::SolidQueue::ClaimedExecution).not_to receive(:count)
            expect(::SolidQueue::Queue).not_to receive(:all)

            Honeybadger::Plugin.instances[:solid_queue].collectors.each do |options, collect_block|
              Honeybadger::Plugin::CollectorExecution.new("solid_queue", config, options, &collect_block).call
            end
          end
        end

        context "when not running in a SolidQueue supervisor process" do
          let(:supervisor) { false }

          it "does not collect stats" do
            expect(::SolidQueue::ClaimedExecution).not_to receive(:count)
            expect(::SolidQueue::Queue).not_to receive(:all)

            Honeybadger::Plugin.instances[:solid_queue].collectors.each do |options, collect_block|
              Honeybadger::Plugin::CollectorExecution.new("solid_queue", config, options, &collect_block).call
            end
          end
        end
      end
    end
  end
end
