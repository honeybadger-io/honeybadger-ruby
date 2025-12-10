require "honeybadger/rack/user_informer"
require "honeybadger/config"

RSpec.describe Honeybadger::Rack::UserInformer do
  let(:agent) { Honeybadger::Agent.new }
  let(:config) { agent.config }

  it "modifies output if there is a honeybadger id" do
    main_app = lambda do |env|
      env["honeybadger.error_id"] = 1
      [200, {}, ["<!-- HONEYBADGER ERROR -->"]]
    end
    informer_app = Honeybadger::Rack::UserInformer.new(main_app, agent)

    result = informer_app.call({})

    expect(result[2][0]).to eq "Honeybadger Error 1"
    expect(result[1]["Content-Length"].to_i).to eq 19
  end

  it "does not modify output if there is no honeybadger id" do
    main_app = lambda do |env|
      [200, {}, ["<!-- HONEYBADGER ERROR -->"]]
    end
    informer_app = Honeybadger::Rack::UserInformer.new(main_app, agent)

    result = informer_app.call({})

    expect(result[2][0]).to eq "<!-- HONEYBADGER ERROR -->"
  end
end
