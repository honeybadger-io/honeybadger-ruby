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
    stub_http(:response => Net::HTTPError, :body => nil)
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
    stub_http(:response => Net::HTTPError)
    Honeybadger.should_receive(:write_verbose_log).with(/Environment Info:/)
    Honeybadger.should_receive(:write_verbose_log).with(/Response from Honeybadger:/)
    send_notice
  end

  context "429 error response" do
    let(:failure_class) do
      if RUBY_VERSION !~ /^1/
        Net::HTTPTooManyRequests
      else
        Net::HTTPClientError
      end
    end

    let(:http) { stub_http(:response => failure_class.new('1.2', '429', 'Peace out'), :body => '{"error":"something went wrong"}') }

    before do
      reset_config
      stub_verbose_log
    end

    it "logs the response" do
      http.should_receive(:post).with(Honeybadger::Sender::NOTICES_URI, kind_of(String), kind_of(Hash))
      Honeybadger.should_receive(:write_verbose_log).with(/Failure: #{failure_class.name}/, :error)
      Honeybadger.should_receive(:write_verbose_log).with(/Environment Info:/)
      Honeybadger.should_receive(:write_verbose_log).with(/something went wrong/)
      Honeybadger.notify(RuntimeError.new('oops!'))
    end
  end
end
