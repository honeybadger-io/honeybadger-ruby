require 'spec_helper'

describe Honeybadger do
  def send_notice
    Honeybadger.sender.send_to_honeybadger('data')
  end

  def stub_verbose_log
    Honeybadger.stub(:write_verbose_log)
  end

  def configure
    Honeybadger.configure { |config| }
  end

  it "reports that notifier is ready when configured" do
    stub_verbose_log
    Honeybadger.should_receive(:write_verbose_log).with(/Notifier (.*) ready/, anything)
    configure
  end

  it "does not report that notifier is ready when internally configured" do
    stub_verbose_log
    Honeybadger.should_not_receive(:write_verbose_log)
    Honeybadger.configure(true) { |config| }
  end

  it "prints environment info on a failed notification without a body" do
    reset_config
    stub_verbose_log
    stub_http(:response => Faraday::Response.new(:status => 500), :body => nil)
    Honeybadger.should_receive(:write_verbose_log).with(/Environment Info:/)
    Honeybadger.should_not_receive(:write_verbose_log).with(/Response from Honeybadger:/, anything)
    send_notice
  end

  it "prints environment info and response on a success with a body" do
    reset_config
    stub_verbose_log
    stub_http
    Honeybadger.should_receive(:write_verbose_log).with(/Environment Info:/)
    Honeybadger.should_receive(:write_verbose_log).with(/Response from Honeybadger:/)
    send_notice
  end

  it "prints environment info and response on a failure with a body" do
    reset_config
    stub_verbose_log
    stub_http(:response => Faraday::Response.new(:status => 500))
    Honeybadger.should_receive(:write_verbose_log).with(/Environment Info:/)
    Honeybadger.should_receive(:write_verbose_log).with(/Response from Honeybadger:/)
    send_notice
  end
end
