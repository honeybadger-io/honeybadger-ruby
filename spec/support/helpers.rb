module Helpers
  def assert_no_difference(expression, message = nil, &block)
    assert_difference expression, 0, message, &block
  end

  def stub_sender
    double('sender', :send_to_honeybadger => nil)
  end

  def stub_sender!
    Honeybadger.sender = stub_sender
  end

  def stub_notice
    Honeybadger::Notice.new({}).tap do |notice|
      notice.stub(:ignored? => false, :to_json => '{"foo":"bar"}')
    end
  end

  def stub_notice!
     stub_notice.tap do |notice|
       Honeybadger::Notice.stub(:new => notice)
    end
  end

  def stub_http(options = {})
    response = options[:response] || Net::HTTPSuccess.new('1.2', '200', 'OK')
    response.stub(:body => options[:body] || '{"id":"1234"}')
    http = double(:post          => response,
                :read_timeout= => nil,
                :open_timeout= => nil,
                :ca_file=      => nil,
                :verify_mode=  => nil,
                :use_ssl=      => nil)
    Net::HTTP.stub(:new).and_return(http)
    http
  end

  def reset_config
    Honeybadger.configuration = nil
    Honeybadger.configure do |config|
      config.api_key = 'abc123'
    end
  end

  def build_notice_data(exception = nil)
    exception ||= build_exception
    {
      :api_key       => nil,
      :error_class   => exception.class.name,
      :error_message => "#{exception.class.name}: #{exception.message}",
      :backtrace     => exception.backtrace,
      :environment   => { 'PATH' => '/bin', 'REQUEST_URI' => '/users/1' },
      :request       => {
        :params     => { 'controller' => 'users', 'action' => 'show', 'id' => '1' },
        :rails_root => '/path/to/application',
        :url        => "http://test.host/users/1"
      },
      :session       => {
        :key  => '123abc',
        :data => { 'user_id' => '5', 'flash' => { 'notice' => 'Logged in successfully' } }
      }
    }
  end

  def build_exception(opts = {})
    backtrace = ["test/honeybadger/rack_test.rb:15:in `build_exception'",
                 "test/honeybadger/rack_test.rb:52:in `test_delivers_exception_from_rack'",
                 "/Users/josh/Developer/.rvm/gems/ruby-1.9.3-p0/gems/mocha-0.10.5/lib/mocha/integration/mini_test/version_230_to_262.rb:28:in `run'"]
    opts = { :backtrace => backtrace }.merge(opts)
    BacktracedException.new(opts)
  end

  def assert_array_starts_with(expected, actual)
    expect(actual).to respond_to :to_ary
    array = actual.to_ary.reverse
    expected.reverse.each_with_index do |value, i|
      expect(array[i]).to eq value
    end
  end

  def assert_logged(expected)
    assert_received(Honeybadger, :write_verbose_log) do |expect|
      expect.with {|actual, level| actual =~ expected }
    end
  end

  def assert_not_logged(expected)
    assert_received(Honeybadger, :write_verbose_log) do |expect|
      expect.with {|actual, level| actual =~ expected }.never
    end
  end

  def assert_caught_and_sent
    expect(Honeybadger.sender.collected).not_to be_empty
  end

  def assert_caught_and_not_sent
    expect(Honeybadger.sender.collected).to be_empty
  end
end
