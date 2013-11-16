require 'spec_helper'
require 'sham_rack'

describe Honeybadger::UserFeedback do
  it 'modifies output if there is a honeybadger id' do
    main_app = lambda do |env|
      env['honeybadger.error_id'] = 1
      [200, {}, ["<!-- HONEYBADGER FEEDBACK -->"]]
    end

    informer_app = Honeybadger::UserFeedback.new(main_app)

    ShamRack.mount(informer_app, "example.com")

    rendered_length = informer_app.feedback_form(1).size

    response = Net::HTTP.get_response(URI.parse("http://example.com/"))
    expect(response.body).to match(/honeybadger_feedback_token/)
    expect(response["Content-Length"].to_i).to eq rendered_length
  end

  it 'does not modify output if there is no honeybadger id' do
    main_app = lambda do |env|
      [200, {}, ["<!-- HONEYBADGER FEEDBACK -->"]]
    end
    informer_app = Honeybadger::UserFeedback.new(main_app)

    ShamRack.mount(informer_app, "example.com")

    response = Net::HTTP.get_response(URI.parse("http://example.com/"))
    expect(response.body).to eq '<!-- HONEYBADGER FEEDBACK -->'
  end
end
