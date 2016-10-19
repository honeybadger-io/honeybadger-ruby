begin
  require 'rails'
  RAILS_PRESENT = true
rescue LoadError
  RAILS_PRESENT = false
  puts 'Skipping Rails integration specs.'
end

if RAILS_PRESENT
  require_relative 'rails/app'
  require 'honeybadger/init/rails'
  require 'rspec/rails'

  describe 'Rails integration', type: :request do
    before(:all) do
      RailsApp.initialize!
    end

    before(:each) do
      Honeybadger.configure do |config|
        config.api_key = 'gem testing'
        config.backend = 'test'
      end
    end

    after(:each) do
      Honeybadger::Backend::Test.notifications[:notices].clear
    end

    it "inserts the middleware" do
      expect(RailsApp.middleware).to include(Honeybadger::Rack::ErrorNotifier)
    end

    it "reports exceptions" do
      Honeybadger.flush do
        get '/runtime_error'
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
        Honeybadger.flush do
          get '/record_not_found'
          expect(response.status).to eq(500)
        end

        expect(Honeybadger::Backend::Test.notifications[:notices]).to be_empty
      end
    end
  end
end
