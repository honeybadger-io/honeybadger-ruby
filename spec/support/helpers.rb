module Helpers
  def stub_http(options = {})
    response = options[:response] || Net::HTTPSuccess.new('1.2', '200', 'OK')
    allow(response).to receive(:body).and_return(options[:body] || '{"id":"1234"}')
    http = double(:post          => response,
                :read_timeout= => nil,
                :open_timeout= => nil,
                :ca_file=      => nil,
                :verify_mode=  => nil,
                :use_ssl=      => nil)
    allow(Net::HTTP).to receive(:new).and_return(http)
    http
  end

  def build_exception(opts = {})
    backtrace = ["test/honeybadger/rack_test.rb:15:in `build_exception'",
                 "test/honeybadger/rack_test.rb:52:in `test_delivers_exception_from_rack'",
                 "/Users/josh/Developer/.rvm/gems/ruby-1.9.3-p0/gems/mocha-0.10.5/lib/mocha/integration/mini_test/version_230_to_262.rb:28:in `run'"]
    opts = {backtrace: backtrace}.merge(opts)
    BacktracedException.new(opts)
  end

  def stub_notice(config = Honeybadger::Config.new(logger: NULL_LOGGER))
    Honeybadger::Notice.new(config, {}).tap do |notice|
      allow(notice).to receive(:ignore?).and_return(false)
      allow(notice).to receive(:to_json).and_return('{"foo":"bar"}')
      yield(notice) if block_given?
    end
  end

  def stub_notice!(*args, &block)
    stub_notice(*args, &block).tap do |notice|
      allow(Honeybadger::Notice).to receive(:new).and_return(notice)
    end
  end
end
