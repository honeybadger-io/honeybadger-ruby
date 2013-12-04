require 'spec_helper'
require 'sham_rack'

describe Honeybadger::UserFeedback do
  let(:main_app) do
    lambda do |env|
      env['honeybadger.error_id'] = honeybadger_id if defined?(honeybadger_id)
      [200, {}, ["<!-- HONEYBADGER FEEDBACK -->"]]
    end
  end
  let(:informer_app) { Honeybadger::UserFeedback.new(main_app) }
  let(:response) { Net::HTTP.get_response(URI.parse("http://example.com/")) }

  before do
    ShamRack.mount(informer_app, "example.com")
  end

  context "feedback feature is disabled by ping" do
    it 'does not modify the output' do
      expect(response.body).to eq '<!-- HONEYBADGER FEEDBACK -->'
    end
  end

  context "feedback feature is enabled by ping" do
    before do
      Honeybadger.configuration.features['feedback'] = true
    end

    context "there is a honeybadger id" do
      let(:honeybadger_id) { 1 }

      it 'modifies output' do
        rendered_length = informer_app.render_form(1).size
        expect(response.body).to match(/honeybadger_feedback_token/)
        expect(response["Content-Length"].to_i).to eq rendered_length
      end

      context "feedback feature is disabled by customer" do
        before do
          Honeybadger.configuration.feedback = false
        end

        it 'does not modify the output' do
          expect(response.body).to eq '<!-- HONEYBADGER FEEDBACK -->'
        end
      end
    end

    context "there is no honeybadger id" do
      it 'does not modify the output' do
        expect(response.body).to eq '<!-- HONEYBADGER FEEDBACK -->'
      end
    end
  end
end
