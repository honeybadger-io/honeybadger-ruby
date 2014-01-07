require 'spec_helper'

describe Honeybadger do
  let(:error_response) { Net::HTTPServerError.new('1.2', 429, 'Too Many Requests') }

  def send_notice
    Honeybadger.sender.send_to_honeybadger({})
  end

  def stub_verbose_log
    Honeybadger.stub(:write_verbose_log)
  end

  def configure
    Honeybadger.configure { |config| }
  end

  it "reports that notifier is ready when configured" do
    stub_verbose_log
    Honeybadger.should_receive(:write_verbose_log).with(/Environment Info:/, :info)
    Honeybadger.should_receive(:write_verbose_log).with(/Notifier (.*) ready/, :info)
    configure
  end

  it "does not report that notifier is ready when internally configured" do
    stub_verbose_log
    Honeybadger.should_not_receive(:write_verbose_log)
    Honeybadger.configure(true) { |config| }
  end

  it "prints response on a failed notification without a body" do
    stub_verbose_log
    stub_http(:response => error_response, :body => nil)
    Honeybadger.should_receive(:write_verbose_log).with(/Response from Honeybadger:/, :debug)
    send_notice
  end

  it "prints response on a success with a body" do
    stub_verbose_log
    stub_http
    Honeybadger.should_receive(:write_verbose_log).with(/Response from Honeybadger:/, :debug)
    send_notice
  end

  it "prints response body on a success with a body" do
    stub_verbose_log
    stub_http(:body => 'this is a failure message')
    Honeybadger.should_receive(:write_verbose_log).with(/this is a failure message/, :debug)
    send_notice
  end

  it "prints response on a failure with a body" do
    stub_verbose_log
    stub_http(:response => error_response, :body => 'this is a failure message')
    Honeybadger.should_receive(:write_verbose_log).with(/Response from Honeybadger:/, :debug)
    send_notice
  end

  it "prints response body on a failure with a body" do
    stub_verbose_log
    stub_http(:response => error_response, :body => 'this is a failure message')
    Honeybadger.should_receive(:write_verbose_log).with(/this is a failure message/, :debug)
    send_notice
  end
end
