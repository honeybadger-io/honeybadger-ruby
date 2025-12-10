require_relative "../rails_helper"

return unless RAILS_PRESENT

Honeybadger.configure do |config|
  config.backend = "test"
end

describe "Rails integration", type: :request do
  it "inserts the middleware" do
    expect(RailsApp.middleware).to include(Honeybadger::Rack::ErrorNotifier)
  end

  it "reports exceptions" do
    Honeybadger.flush do
      get "/runtime_error"
      expect(response.status).to eq(500)
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
  end

  it "sets the root from the Rails root" do
    expect(Honeybadger.config.get(:root)).to eq(Rails.root.to_s)
  end

  it "sets the env from the Rails env" do
    expect(Honeybadger.config.get(:env)).to eq(Rails.env)
  end

  context "default ignored exceptions" do
    it "doesn't report exception" do
      Honeybadger.flush { get "/record_not_found" }

      expect(Honeybadger::Backend::Test.notifications[:notices]).to be_empty
    end
  end
end
