require 'honeybadger/plugins/sidekiq'
require 'honeybadger/config'

describe "Sidekiq Dependency" do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:sidekiq].reset!
  end

  context "when sidekiq is not installed" do
    it "fails quietly" do
      expect { Honeybadger::Plugin.instances[:sidekiq].load!(config) }.not_to raise_error
    end
  end

  context "when sidekiq is installed" do
    let(:shim) do
      Class.new do
        def self.configure_server
        end
      end
    end

    let(:sidekiq_options) {{}}
    let(:sidekiq) { double(Sidekiq, error_handlers: [], options: sidekiq_options) }
    let(:chain) { double('chain', :prepend => true) }

    before do
      Object.const_set(:Sidekiq, shim)
      allow(::Sidekiq).to receive(:configure_server).and_yield(sidekiq)
      allow(sidekiq).to receive(:server_middleware).and_yield(chain)
    end

    after { Object.send(:remove_const, :Sidekiq) }

    context "when version is less than 3" do
      before do
        ::Sidekiq.const_set(:VERSION, '2.17.7')
      end

      it "adds the server middleware" do
        expect(chain).to receive(:prepend).with(Honeybadger::Plugins::Sidekiq::Middleware)
        Honeybadger::Plugin.instances[:sidekiq].load!(config)
      end

      it "doesn't add the error handler" do
        Honeybadger::Plugin.instances[:sidekiq].load!(config)
        expect(sidekiq.error_handlers).to be_empty
      end
    end

    context "when version is 3 or greater" do
      before do
        ::Sidekiq.const_set(:VERSION, '3.0.0')
      end

      it "adds the error handler" do
        Honeybadger::Plugin.instances[:sidekiq].load!(config)
        expect(sidekiq.error_handlers).not_to be_empty
      end

      describe "error handler" do
        let(:exception) { RuntimeError.new('boom') }
        let(:retry_config) { true }
        let(:attempt) { 1 }
        let(:job) { { 'retry' => retry_config, 'retry_count' => attempt == 1 ? nil : attempt - 1} }

        before do
          Honeybadger::Plugin.instances[:sidekiq].load!(config)
        end

        context 'Sidekiq 4.2.3 and later' do
          # The data we're interested in is inside the job subhash
          let(:job_context) { {context: 'Job raised exception', job: job } }

          it "notifies Honeybadger" do
            expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: nil }).once
            sidekiq.error_handlers[0].call(exception, job_context)
          end

          context "when an attempt threshold is configured" do
            let(:attempt) { 1 }
            let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, :'sidekiq.attempt_threshold' => 3) }

            it "doesn't notify Honeybadger" do
              expect(Honeybadger).not_to receive(:notify)
              sidekiq.error_handlers[0].call(exception, job_context)
            end

            context "and the retries are exhausted" do
              let(:retry_config) { 1 }
              let(:attempt) { 2 }

              it "notifies Honeybadger" do
                expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: nil }).once
                sidekiq.error_handlers[0].call(exception, job_context)
              end
            end

            context "and custom max_retries are exausted" do
              let(:sidekiq_options) { { max_retries: 2 } }
              let(:attempt) { 2 }

              it "notifies Honeybadger" do
                expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: nil }).once
                sidekiq.error_handlers[0].call(exception, job_context)
              end
            end

            context "and the attempts meets the threshold" do
              let(:attempt) { 3 }

              it "notifies Honeybadger" do
                expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: nil }).once
                sidekiq.error_handlers[0].call(exception, job_context)
              end
            end
          end

          context "when the class info is present" do
            let(:job) { { 'class' => 'HardWorker' } }

            it "includes the class as a component" do
              expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: 'HardWorker', action: 'perform' }).once
              sidekiq.error_handlers[0].call(exception, job_context)
            end
          end

          context "when the worker is wrapped" do
            let(:job) { { 'class' => 'HardWorker', 'wrapped' => 'WrappedWorker' } }

            it "includes the class as a component" do
              expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: 'WrappedWorker', action: 'perform' }).once
              sidekiq.error_handlers[0].call(exception, job_context)
            end
          end
        end

        context 'Sidekiq earlier than 4.2.3' do
          # The data we're interested in is at the top level of the params
          let(:job_context) { job }

          it "notifies Honeybadger" do
            expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: nil }).once
            sidekiq.error_handlers[0].call(exception, job_context)
          end

          context "when an attempt threshold is configured" do
            let(:attempt) { 1 }
            let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true, :'sidekiq.attempt_threshold' => 3) }

            it "doesn't notify Honeybadger" do
              expect(Honeybadger).not_to receive(:notify)
              sidekiq.error_handlers[0].call(exception, job_context)
            end

            context "and the retries are exhausted" do
              let(:attempt) { 2 }
              let(:retry_config) { 1 }

              it "notifies Honeybadger" do
                expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: nil }).once
                sidekiq.error_handlers[0].call(exception, job_context)
              end
            end

            context "and the attempts meets the threshold" do
              let(:attempt) { 3 }

              it "notifies Honeybadger" do
                expect(Honeybadger).to receive(:notify).with(exception, { parameters: job_context, component: nil }).once
                sidekiq.error_handlers[0].call(exception, job_context)
              end
            end
          end
        end
      end
    end
  end
end
