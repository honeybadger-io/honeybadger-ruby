describe Honeybadger::Rack::MetricsReporter do
  let(:logger) { double(add: true) }
  let(:config) { Honeybadger::Config.new(logger: logger) }
  let(:app) { lambda{} }

  it "logs a deprecation warning when initialized" do
    expect(logger).to receive(:add).with(2, /DEPRECATION/)
    described_class.new(app, config)
  end

  it "calls through app (noop)" do
    app = double(call: :foo)
    expect(described_class.new(app, config).call(app)).to eq(:foo)
  end
end
