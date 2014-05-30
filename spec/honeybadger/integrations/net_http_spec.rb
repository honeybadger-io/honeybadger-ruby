require 'spec_helper'

begin
  require 'active_support/notifications'
rescue LoadError
  nil
end

describe "Net::HTTP Dependency" do
  before do
    Honeybadger::Dependency.reset!
  end

  if defined?(ActiveSupport::Notifications)
    context "when active support notifications are installed" do
      it "installs instrumentation" do
        Honeybadger::Dependency.inject!
        expect(Net::HTTP.instance_method(:request)).to eq Net::HTTP.instance_method(:request_with_honeybadger)
      end
    end
  else
    context "when active support notifications are not installed" do
      it "does not install instrumentation" do
        Honeybadger::Dependency.inject!
        expect(Net::HTTP.instance_methods).not_to include(:request_with_honeybadger)
      end
    end
  end
end
