require 'honeybadger/logger'

RSpec.describe Honeybadger::Logger do
  before do
    Honeybadger::Logger.instance_variable_set(:@appender, nil)
    Honeybadger::Backend::Test.notifications[:logs] = []
    Honeybadger.config[:backend] = :test
  end

  after do
    Honeybadger::Logger.instance_variable_get(:@appender).shutdown!
  end

  it 'waits until the batch is full before sending messages' do
    ::Honeybadger.config[:"logger.batch_size"] = 2
    ::Honeybadger.config[:"logger.batch_interval"] = 60

    Honeybadger::Logger.info("A message", some: 'data')
    sleep 0.1
    expect(Honeybadger::Backend::Test.notifications[:logs].size).to eq(0)

    Honeybadger::Logger.info("Another message", some: 'data')
    sleep 0.1
    expect(Honeybadger::Backend::Test.notifications[:logs].size).to eq(1)

    logs = Honeybadger::Backend::Test.notifications[:logs][0].split("\n").map { |log| JSON[log] }
    expect(logs.size).to eq(2)
    expect(logs[0]["message"]).to eq("A message")
    expect(logs[1]["message"]).to eq("Another message")
    expect(logs[0]["level"]).to eq("info")
    expect(logs[1]["payload"]).to eq({"some" => "data"})
  end

  it 'sends a batch which is not full if the batch timeout is reached' do
    ::Honeybadger.config[:"logger.batch_size"] = 200
    ::Honeybadger.config[:"logger.batch_interval"] = 0.001

    Honeybadger::Logger.info("A message", some: 'data')
    sleep 0.1
    expect(Honeybadger::Backend::Test.notifications[:logs].size).to eq(1)

    logs = Honeybadger::Backend::Test.notifications[:logs][0].split("\n").map { |log| JSON[log] }
    expect(logs.size).to eq(1)
    expect(logs[0]["message"]).to eq("A message")
    expect(logs[0]["level"]).to eq("info")
    expect(logs[0]["payload"]).to eq({"some" => "data"})
  end

  it 'retries a failed batch later'
end