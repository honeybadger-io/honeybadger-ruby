require 'spec_helper'

module ActiveSupport; end

describe "Net::HTTP Dependency" do
  before do
    Honeybadger::Dependency.reset!
  end

  context "when net/http is not required" do
    it "does not install instrumentation" do
      Honeybadger::Dependency.inject!
      expect(Net::HTTP.instance_methods).not_to include(:request_with_honeybadger)
    end
  end

  context "when active_support notifications is required" do
    before do
      class ActiveSupport::Notifications
      end
    end

    it "installs instrumentation" do
      Honeybadger::Dependency.inject!
      expect(Net::HTTP.instance_method(:request)).to eq Net::HTTP.instance_method(:request_with_honeybadger)
    end
  end
end
