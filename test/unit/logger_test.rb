require 'test_helper'

class LoggerTest < Test::Unit::TestCase
  def stub_http(response, body = nil)
    response.stubs(:body => body) if body
    @http = stub(:post => response,
                 :read_timeout= => nil,
                 :open_timeout= => nil,
                 :use_ssl= => nil,
                 :ca_file= => nil,
                 :verify_mode= => nil)
    Net::HTTP.stubs(:new).returns(@http)
  end

  def send_notice
    Honeybadger.sender.send_to_honeybadger('data')
  end

  def stub_verbose_log
    Honeybadger.stubs(:write_verbose_log)
  end

  def configure
    Honeybadger.configure { |config| }
  end

  should "report that notifier is ready when configured" do
    stub_verbose_log
    configure
    assert_logged /Notifier (.*) ready/
  end

  should "not report that notifier is ready when internally configured" do
    stub_verbose_log
    Honeybadger.configure(true) { |config| }
    assert_not_logged /.*/
  end

  should "print environment info a successful notification without a body" do
    reset_config
    stub_verbose_log
    stub_http(Net::HTTPSuccess)
    send_notice
    assert_logged /Environment Info:/
    assert_not_logged /Response from Honeybadger:/
  end

  should "print environment info on a failed notification without a body" do
    reset_config
    stub_verbose_log
    stub_http(Net::HTTPError)
    send_notice
    assert_logged /Environment Info:/
    assert_not_logged /Response from Honeybadger:/
  end

  should "print environment info and response on a success with a body" do
    reset_config
    stub_verbose_log
    stub_http(Net::HTTPSuccess, '{}')
    send_notice
    assert_logged /Environment Info:/
    assert_logged /Response from Honeybadger:/
  end

  should "print environment info and response on a failure with a body" do
    reset_config
    stub_verbose_log
    stub_http(Net::HTTPError, '{}')
    send_notice
    assert_logged /Environment Info:/
    assert_logged /Response from Honeybadger:/
  end
end
