require 'spec_helper'

describe Honeybadger::Stats do
  describe '.memory' do
    subject { Honeybadger::Stats.memory }

    before do
      stub_const('Honeybadger::Stats::HAS_MEM', true)
      IO.stub(:readlines).with('/proc/meminfo').and_return(["MemTotal:       35125476 kB\n", "MemFree:         1671436 kB\n", "Buffers:         2242812 kB\n", "Cached:         11791596 kB\n", "SwapCached:       164256 kB\n", "Active:         15891800 kB\n", "Inactive:       13593872 kB\n"])
    end

    describe '.keys' do
      subject { Honeybadger::Stats.memory.keys }
      it { should eq [:total, :free, :buffers, :cached, :free_total] }
    end

    it 'converts KB to MB' do
      expect(Honeybadger::Stats.memory[:total]).to eq 34302.22265625
      expect(Honeybadger::Stats.memory[:free]).to eq 1632.26171875
      expect(Honeybadger::Stats.memory[:buffers]).to eq 2190.24609375
      expect(Honeybadger::Stats.memory[:cached]).to eq 11515.23046875
    end

    it 'sums non-totals for free_total' do
      expect(Honeybadger::Stats.memory[:free_total]).to eq 15337.73828125
    end

    context 'mathn' do
      before(:all) { require 'mathn' }

      it 'converts Rational to Float' do
        expect(Honeybadger::Stats.memory[:total]).to be_a Float
        expect(Honeybadger::Stats.memory[:free]).to be_a Float
        expect(Honeybadger::Stats.memory[:buffers]).to be_a Float
        expect(Honeybadger::Stats.memory[:cached]).to be_a Float
      end
    end
  end
end
