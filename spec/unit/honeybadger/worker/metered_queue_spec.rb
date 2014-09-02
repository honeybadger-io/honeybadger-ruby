require 'timecop'
require 'honeybadger/worker/metered_queue'

describe Honeybadger::Worker::MeteredQueue do
  let(:now) { Time.now }
  let(:queue) { described_class.new(10, 2, now) }

  around {|e| Timecop.freeze(now, &e) }

  describe "#push" do
    before do
      queue.push(1)
    end

    context "when the limit is not reached" do
      it "adds the value to the queue" do
        expect { queue.push(2) }.to change(queue, :size).by(1)
      end
    end

    context "when the limit is reached" do
      before do
        queue.push(2)
      end

      it "does not add the value to the queue" do
        expect { queue.push(3) }.not_to change(queue, :size)
      end
    end
  end

  describe "#pop" do
    before do
      queue.push(1)
      queue.push(2)
    end

    it "returns a value at the defined interval" do
      expect(queue.pop).to be_nil
      Timecop.travel(10)
      expect(queue.pop).to eq 1
      expect(queue.pop).to be_nil
      Timecop.travel(10)
      expect(queue.pop).to eq 2
    end

    context "with a throttle" do
      before { queue.throttle(2) }

      it "returns a value at the throttled interval" do
        Timecop.travel(10)
        expect(queue.pop).to be_nil
        Timecop.travel(10)
        expect(queue.pop).to eq 1
        Timecop.travel(10)
        expect(queue.pop).to be_nil
        Timecop.travel(10)
        expect(queue.pop).to eq 2
      end

      context "with multiple throttles" do
        before do
          queue.throttle(3)
          Timecop.travel(60)
          queue.pop
        end

        it "applies throttles exponentially" do
          Timecop.travel(55)
          expect(queue.pop).to be_nil
          Timecop.travel(5) # total distance of 60 seconds (10*20*30)
          expect(queue.pop).to eq 2
        end
      end
    end
  end

  describe "#pop!" do
    before do
      queue.push(1)
    end

    it "returns value immediately" do
      expect(queue.pop!).to eq 1
    end
  end

  describe "#throttle" do
    before do
      queue.push(1)
      queue.push(2)
      queue.throttle(1.5)
    end

    it "adds the difference to the current future" do
      Timecop.travel(10)
      expect(queue.pop).to be_nil
      Timecop.travel(5)
      expect(queue.pop).to eq 1
    end

    context "with multiple throttles" do
      before do
        queue.throttle(1.5)
      end

      it "adds the difference to the new future" do
        Timecop.travel(15)
        expect(queue.pop).to be_nil
        Timecop.travel(15)
        expect(queue.pop).to eq 1
      end
    end
  end

  describe "#unthrottle" do
    before do
      queue.push(1)
      queue.push(2)
      queue.throttle(1.5)
    end

    it "returns the last throttle added" do
      queue.throttle(2)
      expect(queue.unthrottle).to eq 2
    end

    it "subtracts the difference from the current future" do
      Timecop.travel(5)
      expect(queue.pop).to be_nil
      expect(queue.unthrottle).to eq 1.5
      Timecop.travel(5)
      expect(queue.pop).to eq 1
    end

    context "with multiple throttles" do
      before do
        queue.throttle(2)
      end

      it "subtracts the difference from the new future" do
        expect(queue.unthrottle).to eq 2
        expect(queue.unthrottle).to eq 1.5
        Timecop.travel(5)
        expect(queue.pop).to be_nil
        Timecop.travel(5)
        expect(queue.pop).to eq 1
      end
    end
  end
end
