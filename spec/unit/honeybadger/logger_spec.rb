require 'honeybadger/logger'

RSpec.describe Honeybadger::Logger do
  let(:mock_http) { double(SemanticLogger::Appender::Http) }
  let(:received_batches) { [] }

  before do
    Honeybadger.logger.instance_variable_set(:@appender, nil)
    allow(SemanticLogger::Appender::Http).to receive(:new).and_return(mock_http)
    allow(mock_http).to receive(:post) do |payload|
      received_batches << payload
      true
    end
  end

  after do
    Honeybadger.logger.instance_variable_get(:@appender).shutdown!
  end

  def wait_for_other_thread(wait = 0.05)
    yield
    sleep wait
  end

  it 'waits until the batch is full before sending messages' do
    Honeybadger.config[:"features.logger.batch_size"] = 2
    Honeybadger.config[:"features.logger.batch_interval"] = 60

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
    Honeybadger.config[:"features.logger.batch_size"] = 200
    Honeybadger.config[:"features.logger.batch_interval"] = 0.001

    wait_for_other_thread { Honeybadger.logger.warn("A message", some: 'data') }
    wait_for_other_thread { Honeybadger.logger.info("Another message", some: 'data') }

    expect(received_batches.size).to eq(2)

    batch_1, batch_2 = received_batches
    expect(JSON[batch_1]["message"]).to eq("A message")
    expect(JSON[batch_2]["message"]).to eq("Another message")
  end

  it 'retries a failed batch when another batch succeeds' do
    Honeybadger.config[:"features.logger.batch_size"] = 200
    Honeybadger.config[:"features.logger.batch_interval"] = 0.001

    expect(mock_http).to receive(:post).twice { false }
    # Four messages across three batches, with the first two batches failing
    wait_for_other_thread do
      Honeybadger.logger.debug("First - fails")
      Honeybadger.logger.debug("Second - fails")
    end
    wait_for_other_thread { Honeybadger.logger.debug("Third - fails") }

    expect(received_batches.size).to eq(0)

    expect(mock_http).to receive(:post).exactly(3).times do |payload|
      received_batches << payload
      true
    end
    wait_for_other_thread { Honeybadger.logger.error("Fourth - succeeds") }

    expect(received_batches.size).to eq(3)

    logs = received_batches.flat_map { |batch| batch.split("\n").map { |log| JSON[log] } }
    expect(logs.size).to eq(4)
    expect(logs.map { |l| l["message"] }).to eq(
      ["Fourth - succeeds", "First - fails", "Second - fails", "Third - fails"]
    )
  end
end
