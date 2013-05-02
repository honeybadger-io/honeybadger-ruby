require 'test/unit'

require 'mocha'
require 'shoulda'
require 'bourne'
require 'rack'

require 'honeybadger'

class BacktracedException < Exception
  attr_accessor :backtrace
  def initialize(opts)
    @backtrace = opts[:backtrace]
  end
  def set_backtrace(bt)
    @backtrace = bt
  end
end

module DefinesConstants
  def setup
    @defined_constants = []
  end

  def teardown
    @defined_constants.each do |constant|
      Object.__send__(:remove_const, constant)
    end
  end

  def define_constant(name, value)
    Object.const_set(name, value)
    @defined_constants << name
  end
end

module SettingEnvironment

  def set_public_env
    Honeybadger.configure { |config| config.environment_name = 'production' }
  end

  def set_development_env
    Honeybadger.configure { |config| config.environment_name = 'development' }
  end

  def set_test_env
    Honeybadger.configure { |config| config.environment_name = 'test' }
  end

end


class CollectingSender
  attr_reader :collected

  def initialize
    @collected = []
  end

  def send_to_honeybadger(notice)
    data = notice.respond_to?(:to_json) ? notice.to_json : notice
    @collected << data
  end
end

class Test::Unit::TestCase
  def teardown
    Honeybadger.context.clear!
  end

  def assert_no_difference(expression, message = nil, &block)
    assert_difference expression, 0, message, &block
  end

  def stub_sender
    stub('sender', :send_to_honeybadger => nil)
  end

  def stub_sender!
    Honeybadger.sender = stub_sender
  end

  def stub_notice
    Honeybadger::Notice.new({}).tap do |notice|
      notice.stubs(:ignored? => false, :to_json => '{"foo":"bar"}')
    end
  end

  def stub_notice!
     stub_notice.tap do |notice|
       Honeybadger::Notice.stubs(:new => notice)
    end
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
      :api_key       => 'abc123',
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
    assert_respond_to actual, :to_ary
    array = actual.to_ary.reverse
    expected.reverse.each_with_index do |value, i|
      assert_equal value, array[i]
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
    assert !Honeybadger.sender.collected.empty?
  end

  def assert_caught_and_not_sent
    assert Honeybadger.sender.collected.empty?
  end
end
