require "honeybadger/rack/user_informer"
require "honeybadger/config"

describe Honeybadger::Rack::UserInformer do
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
    expect(result[1]["content-length"].to_i).to eq 19
  end

  it "does not modify output if there is no honeybadger id" do
    main_app = lambda do |env|
      [200, {}, ["<!-- HONEYBADGER ERROR -->"]]
    end
    informer_app = Honeybadger::Rack::UserInformer.new(main_app, agent)

    result = informer_app.call({})

    expect(result[2][0]).to eq "<!-- HONEYBADGER ERROR -->"
  end

  it "removes Transfer-Encoding header when setting Content-Length" do
    main_app = lambda do |env|
      env["honeybadger.error_id"] = 1
      [200, {"Transfer-Encoding" => "chunked"}, ["<!-- HONEYBADGER ERROR -->"]]
    end
    informer_app = Honeybadger::Rack::UserInformer.new(main_app, agent)

    result = informer_app.call({})

    expect(result[1]["Transfer-Encoding"]).to be_nil
    expect(result[1]["content-length"].to_i).to eq 19
  end

  it "removes lowercase transfer-encoding header (Rack 3 style)" do
    main_app = lambda do |env|
      env["honeybadger.error_id"] = 1
      [200, {"transfer-encoding" => "chunked"}, ["<!-- HONEYBADGER ERROR -->"]]
    end
    informer_app = Honeybadger::Rack::UserInformer.new(main_app, agent)

    result = informer_app.call({})

    expect(result[1]["transfer-encoding"]).to be_nil
    expect(result[1]["content-length"].to_i).to eq 19
  end

  it "normalizes duplicate Content-Length headers" do
    main_app = lambda do |env|
      env["honeybadger.error_id"] = 1
      [200, {"content-length" => "100", "Content-Length" => "100"}, ["<!-- HONEYBADGER ERROR -->"]]
    end
    informer_app = Honeybadger::Rack::UserInformer.new(main_app, agent)

    result = informer_app.call({})

    expect(result[1]["Content-Length"]).to be_nil
    expect(result[1]["content-length"].to_i).to eq 19
  end
end
