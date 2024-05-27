require 'honeybadger/instrumentation'

describe Honeybadger::Instrumentation do
  before do
    Honeybadger.registry.flush
  end

  describe '.time' do
    context 'by keyword argument' do
      it 'creates a timer object' do
        timer = Honeybadger::Instrumentation.time('test_timer', duration: 0.1)

        expect(timer).to be_a Honeybadger::Timer
        expect(timer.payloads[0][:latest]).to be > 0
      end
    end

    context 'by lambda' do
      it 'creates a timer object' do
        timer = Honeybadger::Instrumentation.time('test_timer', ->{ sleep(0.1) })

        expect(timer).to be_a Honeybadger::Timer
        expect(timer.payloads[0][:latest]).to be > 0
      end
    end

    context 'by block' do
      it 'creates a timer object' do
        timer = Honeybadger::Instrumentation.time('test_timer') { sleep(0.1) }

        expect(timer).to be_a Honeybadger::Timer
        expect(timer.payloads[0][:latest]).to be > 0
      end
    end
  end

  describe '#gauge' do
    context 'by keyword arg' do
      it 'creates a gauge object' do
        gauge = Honeybadger::Instrumentation.gauge('test_gauge', value: 1)
        Honeybadger::Instrumentation.gauge('test_gauge', value: 10)

        expect(gauge).to be_a Honeybadger::Gauge
        expect(gauge.payloads[0][:latest]).to eq(10)
        expect(gauge.payloads[0][:min]).to eq(1)
        expect(gauge.payloads[0][:max]).to eq(10)
        expect(gauge.payloads[0][:avg]).to eq(5.5)
      end
    end

    context 'by lambda' do
      it 'creates a gauge object' do
        gauge = Honeybadger::Instrumentation.gauge('test_gauge', ->{ 1 })
        Honeybadger::Instrumentation.gauge('test_gauge', ->{ 10 })

        expect(gauge).to be_a Honeybadger::Gauge
        expect(gauge.payloads[0][:latest]).to eq(10)
        expect(gauge.payloads[0][:min]).to eq(1)
        expect(gauge.payloads[0][:max]).to eq(10)
        expect(gauge.payloads[0][:avg]).to eq(5.5)
      end
    end

    context 'by block' do
      it 'creates a gauge object' do
        gauge = Honeybadger::Instrumentation.gauge('test_gauge') { 1 }
        Honeybadger::Instrumentation.gauge('test_gauge') { 10 }

        expect(gauge).to be_a Honeybadger::Gauge
        expect(gauge.payloads[0][:latest]).to eq(10)
        expect(gauge.payloads[0][:min]).to eq(1)
        expect(gauge.payloads[0][:max]).to eq(10)
        expect(gauge.payloads[0][:avg]).to eq(5.5)
      end
    end
  end

  describe '#increment_counter' do
    context 'default increment' do
      it 'creates a counter object' do
        counter = Honeybadger::Instrumentation.increment_counter('test_counter')

        expect(counter).to be_a Honeybadger::Counter
        expect(counter.payloads[0][:counter]).to eq(1)
      end
    end

    context 'by keyword arg' do
      it 'creates a counter object' do
        counter = Honeybadger::Instrumentation.increment_counter('test_counter', by: 1)

        expect(counter).to be_a Honeybadger::Counter
        expect(counter.payloads[0][:counter]).to eq(1)
      end
    end

    context 'by lambda' do
      it 'creates a counter object' do
        counter = Honeybadger::Instrumentation.increment_counter('test_counter', ->{ 1 })

        expect(counter).to be_a Honeybadger::Counter
        expect(counter.payloads[0][:counter]).to eq(1)
      end
    end

    context 'by block' do
      it 'creates a counter object' do
        counter = Honeybadger::Instrumentation.increment_counter('test_counter') { 1 }

        expect(counter).to be_a Honeybadger::Counter
        expect(counter.payloads[0][:counter]).to eq(1)
      end
    end
  end

  describe '#decrement_counter' do
    context 'default decrement' do
      it 'creates a counter object' do
        counter = Honeybadger::Instrumentation.decrement_counter('test_counter')

        expect(counter).to be_a Honeybadger::Counter
        expect(counter.payloads[0][:counter]).to eq(-1)
      end
    end

    context 'by keyword arg' do
      it 'creates a counter object' do
        counter = Honeybadger::Instrumentation.decrement_counter('test_counter', by: 1)

        expect(counter).to be_a Honeybadger::Counter
        expect(counter.payloads[0][:counter]).to eq(-1)
      end
    end

    context 'by lambda' do
      it 'creates a counter object' do
        counter = Honeybadger::Instrumentation.decrement_counter('test_counter', ->{ 1 })

        expect(counter).to be_a Honeybadger::Counter
        expect(counter.payloads[0][:counter]).to eq(-1)
      end
    end

    context 'by block' do
      it 'creates a counter object' do
        counter = Honeybadger::Instrumentation.decrement_counter('test_counter') { 1 }

        expect(counter).to be_a Honeybadger::Counter
        expect(counter.payloads[0][:counter]).to eq(-1)
      end
    end
  end

  describe '#histogram' do
    context 'by keyword argument' do
      it 'creates a histogram object' do
        histogram = Honeybadger::Instrumentation.histogram('test_histogram', duration: 0.0001)

        expect(histogram).to be_a Honeybadger::Histogram
        expect(histogram.payloads[0][:bins].map { |b| b[1] }).to include 1
      end
    end

    context 'by lambda' do
      it 'creates a histogram object' do
        histogram = Honeybadger::Instrumentation.histogram('test_histogram', ->{ sleep(0.0001) })

        expect(histogram).to be_a Honeybadger::Histogram
        expect(histogram.payloads[0][:bins].map { |b| b[1] }).to include 1
      end
    end

    context 'by block' do
      it 'creates a histogram object' do
        histogram = Honeybadger::Instrumentation.histogram('test_histogram') { sleep(0.0001) }

        expect(histogram).to be_a Honeybadger::Histogram
        expect(histogram.payloads[0][:bins].map { |b| b[1] }).to include 1
      end
    end
  end
end
