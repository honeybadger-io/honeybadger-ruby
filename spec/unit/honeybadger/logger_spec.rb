require 'honeybadger/logger'

RSpec.describe Honeybadger::Logger do
  before do
    Honeybadger.logger.instance_variable_set(:@appender, nil)
    Honeybadger::Backend::Test.notifications[:logs] = []
    Honeybadger.config[:backend] = :test
  end

  after do
    Honeybadger.logger.instance_variable_get(:@appender).shutdown!
  end

  def received_batches
    Honeybadger::Backend::Test.notifications[:logs]
  end

  def wait_for_other_thread(wait = 0.05)
    yield
    sleep wait
  end

  it 'waits until the batch is full before sending messages' do
    Honeybadger.config[:"logger.batch_size"] = 2
    Honeybadger.config[:"logger.batch_interval"] = 60

    wait_for_other_thread { Honeybadger.logger.info("A message", some: 'data') }
    wait_for_other_thread { Honeybadger.logger.info("Another message", some: 'data') }
    expect(received_batches.size).to eq(1)

    logs = received_batches.first.split("\n").map { |log| JSON[log] }
    expect(logs.size).to eq(2)
    expect(logs[0]["message"]).to eq("A message")
    expect(logs[1]["message"]).to eq("Another message")
    expect(logs[0]["level"]).to eq("info")
    expect(logs[1]["payload"]).to eq({"some" => "data"})
  end

  it 'sends a batch which is not full if the batch timeout is reached' do
    Honeybadger.config[:"logger.batch_size"] = 200
    Honeybadger.config[:"logger.batch_interval"] = 0.001

    wait_for_other_thread { Honeybadger.logger.warn("A message", some: 'data') }
    wait_for_other_thread { Honeybadger.logger.info("Another message", some: 'data') }

    expect(received_batches.size).to eq(2)

    logs = received_batches.first.split("\n").map { |log| JSON[log] }
    expect(logs.size).to eq(1)
    expect(logs[0]["message"]).to eq("A message")
    expect(logs[0]["level"]).to eq("warn")
    expect(logs[0]["payload"]).to eq({"some" => "data"})
  end

  it 'retries a failed batch when another batch succeeds' do
    Honeybadger.config[:"logger.batch_size"] = 200
    Honeybadger.config[:"logger.batch_interval"] = 0.001

    backend = Honeybadger::Backend::Test.new(Honeybadger.config)
    Honeybadger.config[:backend] = backend

    expect(backend).to receive(:notify).twice do
      Honeybadger::Backend::Null::StubbedResponse.new(successful: false)
    end
    wait_for_other_thread { Honeybadger.logger.debug("First - fails") }
    wait_for_other_thread { Honeybadger.logger.debug("Second - fails") }

    expect(received_batches.size).to eq(0)

    expect(backend).to receive(:notify).exactly(3).times.and_call_original
    wait_for_other_thread { Honeybadger.logger.error("Third - succeeds") }

    expect(received_batches.size).to eq(3)

    logs = received_batches.flat_map { |batch| batch.split("\n").map { |log| JSON[log] } }
    expect(logs.size).to eq(3)
    expect(logs.map { |l| l["message"] }).to eq(["Third - succeeds", "First - fails", "Second - fails"])
  end
end