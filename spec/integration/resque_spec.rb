begin
  require "resque"
  require "mock_redis"
  RESQUE_PRESENT = true
rescue LoadError
  RESQUE_PRESENT = false
  puts "Skipping Resque integration specs."
end

if RESQUE_PRESENT
  require "honeybadger"

  ERROR = StandardError.new("This is a failure inside Honeybadger integration test suite")

  class TestWorker
    @queue = :test

    def self.perform
      raise ERROR
    end
  end

  class DirtyWorker
    @queue = :test

    def self.perform
      Resque.shutdown!
    end
  end

  describe "Resque integration" do
    let(:worker) { Resque::Worker.new(:test) }

    before(:all) do
      Resque.redis = MockRedis.new
    end

    it "reports failed jobs to Honeybadger" do
      job = Resque::Job.new(:jobs, {"class" => "TestWorker", "args" => nil})

      expect(Honeybadger).to receive(:notify).once.with(ERROR, anything)

      worker.perform(job)
    end

    it "reports DirtyExit to Honeybadger" do
      job = Resque::Job.new(:jobs, {"class" => "TestWorker", "args" => nil})

      expect(Honeybadger).to receive(:notify).once.with(kind_of(Resque::DirtyExit), anything)

      worker.working_on(job)
      worker.unregister_worker
    end
  end
end
