require 'honeybadger/trace'
require 'honeybadger/config'

describe Honeybadger::Trace do
  describe "::instrument" do
    let(:trace) { Honeybadger::Trace.new(:foo) }

    before do
      allow(Honeybadger::Trace).to receive(:new).and_return(trace)
    end

    it "sends the trace to the agent" do
      expect(Honeybadger::Agent).to receive(:trace).with(trace)
      described_class.instrument('testing', {}){}
    end

    it "includes request data" do
      described_class.instrument('testing', {}){}
      expect(trace.meta).to have_key :request
    end
  end

  describe "#complete" do
    let(:trace) { Honeybadger::Trace.new(:foo) }
    let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER) }
    let(:event) { double('ActiveSupport::Notifications::Event', name: 'process_action.action_controller', duration: 1.2, payload: payload) }
    let(:payload) { {} }

    before do
      allow(Honeybadger::Trace).to receive(:new).and_return(trace)
    end

    context "when completed with an event payload" do
      let(:payload) { { foo: 'bar' } }

      it "includes payload's data" do
        trace.complete(event)
        expect(trace.meta[:foo]).to eq 'bar'
      end
    end

    context "when completed with a local payload" do
      it "includes payload's data" do
        trace.complete(event, { foo: 'bar' })
        expect(trace.meta[:foo]).to eq 'bar'
      end
    end
  end
end

begin
  require 'active_support/notifications'
  require 'active_record'

  describe Honeybadger::TraceCleaner::ActiveRecord do
    let(:event) do
      ::ActiveSupport::Notifications::Event.new(
        'sql.active_record', # name
        now = Time.now.to_f, # start
        now+0.2,             # ending
        '1',                 # transaction_id
        {                    # payload
          :name => nil,
          :sql => '',
          :binds => [],
          :connection_id => 123
        }
      )
    end

    before do
      allow(::ActiveRecord::Base).to receive(:connection_pool).and_return(double(:spec => double(:config => {})))
    end

    # This will fail if the configuration is accessed through
    # `ActiveRecord::Base.connection_config` in rails < 3.1.
    it "safely accesses connection configuration" do
      expect { described_class.new(event).to_s }.not_to raise_error
    end
  end
rescue LoadError
  nil
end

