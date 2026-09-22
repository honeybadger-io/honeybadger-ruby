require_relative "../rails_helper"

describe "Rails integration", if: RAILS_PRESENT, type: :request do
  load_rails_hooks(self)

  it "inserts the middleware" do
    expect(RailsApp.middleware).to include(Honeybadger::Rack::ErrorNotifier)

    middleware = RailsApp.middleware.map(&:klass)
    expect(middleware.index(Honeybadger::Rack::RequestId)).to eq(middleware.index(ActionDispatch::RequestId) + 1)
  end

  it "reports exceptions" do
    Honeybadger.flush do
      get "/runtime_error"
      expect(response.status).to eq(500)
    end

    expect(Honeybadger::Backend::Test.notifications[:notices].size).to eq(1)
  end

  it "reports the request id assigned by ActionDispatch::RequestId" do
    Honeybadger.flush do
      get "/runtime_error", headers: {"X-Request-Id" => "rails-request-id-12345"}
      expect(response.status).to eq(500)
    end

    notice = Honeybadger::Backend::Test.notifications[:notices].first
    expect(notice.request_id).to eq("rails-request-id-12345")
  end

  it "reports the request id Rails generates when none is sent" do
    Honeybadger.flush do
      get "/runtime_error"
      expect(response.status).to eq(500)
    end

    notice = Honeybadger::Backend::Test.notifications[:notices].first
    expect(notice.request_id).to eq(response.headers["X-Request-Id"])
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
