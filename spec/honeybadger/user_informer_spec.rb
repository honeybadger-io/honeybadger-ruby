require 'spec_helper'
require 'sham_rack'

describe Honeybadger::Rack::UserInformer do
  it 'modifies output if there is a honeybadger id' do
    main_app = lambda do |env|
      env['honeybadger.error_id'] = 1
      [200, {}, ["<!-- HONEYBADGER ERROR -->"]]
    end
    informer_app = Honeybadger::Rack::UserInformer.new(main_app)

    ShamRack.mount(informer_app, "example.com")

    response = Net::HTTP.get_response(URI.parse("http://example.com/"))
    expect(response.body).to eq 'Honeybadger Error 1'
    expect(response["Content-Length"].to_i).to eq 19
  end

  it 'does not modify output if there is no honeybadger id' do
    main_app = lambda do |env|
      [200, {}, ["<!-- HONEYBADGER ERROR -->"]]
    end
    informer_app = Honeybadger::Rack::UserInformer.new(main_app)

    ShamRack.mount(informer_app, "example.com")

    response = Net::HTTP.get_response(URI.parse("http://example.com/"))
    expect(response.body).to eq '<!-- HONEYBADGER ERROR -->'
  end
end
