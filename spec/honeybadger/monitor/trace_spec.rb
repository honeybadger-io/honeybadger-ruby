require 'spec_helper'
require 'honeybadger/monitor'

describe Honeybadger::Monitor::Trace do
  describe "::instrument" do
    it "creates a new trace" do
      Honeybadger::Monitor::Trace.should_receive(:new).and_call_original
      described_class.instrument('testing', {}){}
    end
  end
end

begin
  require 'active_support/notifications'
  require 'active_record'

  describe Honeybadger::Monitor::TraceCleaner::ActiveRecord do
    let(:event) do
      ::ActiveSupport::Notifications::Event.new(
        'sql.active_record', # name
        now = Time.now.to_f, # start
        now+0.2,             # ending
        '1',                 # transaction_id
        {                    # payload
          name: nil,
          sql: '',
          binds: [],
          connection_id: 123
        }
      )
    end

    before do
      ::ActiveRecord::Base.stub(:connection_pool).and_return(double(:spec => double(:config => {})))
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
