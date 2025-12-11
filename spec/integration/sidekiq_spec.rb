begin
  require "ostruct"
  require "sidekiq"
  SIDEKIQ_PRESENT = true
rescue LoadError
  SIDEKIQ_PRESENT = false
end

return unless SIDEKIQ_PRESENT

Sidekiq.define_singleton_method(:server?) { true } # So Sidekiq.configure_server block is run

String.define_method(:constantize) { Object.const_get(self) } if Sidekiq::VERSION < "7"

require "sidekiq/processor"

def run_sidekiq_job(klass, args)
  config = (Sidekiq::VERSION >= "7") ? ::Sidekiq.default_configuration.default_capsule : ::Sidekiq
  processor = Sidekiq::Processor.new(config)

  job_str = {
    "args" => args, "class" => klass.to_s, "jid" => SecureRandom.uuid
  }.to_json
  unit_of_work = OpenStruct.new(job: job_str, queue: "default")
  processor.__send__(:process, unit_of_work)
end

require "honeybadger"

ERROR = StandardError.new("This is a failure inside Honeybadger integration test suite")

class SidekiqJobNoRetry
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(*args)
    raise ERROR
  end
end

RSpec.describe "Sidekiq integration" do
  it "calls the error handler" do
    expect(Honeybadger).to receive(:notify).once.with(ERROR, anything)

    expect { run_sidekiq_job(SidekiqJobNoRetry, ["Tim", 10]) }.to raise_error(ERROR)
  end
end
