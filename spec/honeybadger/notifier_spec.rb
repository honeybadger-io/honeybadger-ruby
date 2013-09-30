require 'spec_helper'

describe 'Honeybadger' do
  class OriginalException < Exception
  end

  class ContinuedException < Exception
  end

  before(:each) do
    reset_config
  end

  def assert_sends(notice, notice_args)
    Honeybadger::Notice.should_receive(:new).with(hash_including(notice_args))
    Honeybadger.sender.should_receive(:send_to_honeybadger).with(notice)
  end

  def set_public_env
    Honeybadger.configure { |config| config.environment_name = 'production' }
  end

  def set_development_env
    Honeybadger.configure { |config| config.environment_name = 'development' }
  end

  it "yields and save a configuration when configuring" do
    yielded_configuration = nil
    Honeybadger.configure do |config|
      yielded_configuration = config
    end

    expect(yielded_configuration).to be_a Honeybadger::Configuration
    expect(yielded_configuration).to be Honeybadger.configuration
  end

  it "does not remove existing config options when configuring twice" do
    first_config = nil
    Honeybadger.configure do |config|
      first_config = config
    end
    Honeybadger.configure do |config|
      expect(config).to be first_config
    end
  end

  it "configures the sender" do
    sender = stub_sender
    Honeybadger::Sender.stub(:new => sender)

    Honeybadger.configure { |yielded_config| Honeybadger::Sender.should_receive(:new).with(yielded_config) }
    expect(Honeybadger.sender).to be sender
  end

  it "creates and send a notice asynchronously" do
    set_public_env
    notice = stub_notice!
    notice_args = { :error_message => 'uh oh' }

    async_expectation = double(:received => true)
    async_handler = Proc.new do |n|
      async_expectation.received
      n.deliver
    end

    Honeybadger.configure do |config|
      config.async = async_handler
    end

    stub_sender!

    async_expectation.should_receive(:received)
    assert_sends(notice, notice_args)

    Honeybadger.notify(notice_args)
  end

  it "creates and send a notice for an exception" do
    set_public_env
    exception = build_exception
    stub_sender!
    notice = stub_notice!

    assert_sends notice, :exception => exception
    Honeybadger.notify(exception)
  end

  it "creates and send a notice for a hash" do
    set_public_env
    notice = stub_notice!
    notice_args = { :error_message => 'uh oh' }
    stub_sender!

    assert_sends(notice, notice_args)
    Honeybadger.notify(notice_args)
  end

  it "does not pass the hash as an exception when sending a notice for it" do
    set_public_env
    stub_notice!
    notice_args = { :error_message => 'uh oh' }
    stub_sender!

    Honeybadger::Notice.should_receive(:new).with(hash_excluding(:exception))
    Honeybadger.notify(notice_args)
  end

  it "creates and send a notice for an exception that responds to to_hash" do
    set_public_env
    exception = build_exception
    notice = stub_notice!
    notice_args = { :error_message => 'uh oh' }
    exception.stub(:to_hash).and_return(notice_args)
    stub_sender!

    assert_sends(notice, notice_args.merge(:exception => exception))
    Honeybadger.notify(exception)
  end

  it "creates and sent a notice for an exception and hash" do
    set_public_env
    exception = build_exception
    notice = stub_notice!
    notice_args = { :error_message => 'uh oh' }
    stub_sender!

    assert_sends(notice, notice_args.merge(:exception => exception))
    Honeybadger.notify(exception, notice_args)
  end

  it "does not create a notice in a development environment" do
    set_development_env
    sender = stub_sender!

    sender.should_receive(:send_to_honeybadger).never

    Honeybadger.notify(build_exception)
    Honeybadger.notify_or_ignore(build_exception)
  end

  it "does not deliver an ignored exception when notifying implicitly" do
    set_public_env
    exception = build_exception
    sender = stub_sender!
    notice = stub_notice!
    notice.stub(:ignore? => true)

    sender.should_receive(:send_to_honeybadger).never

    Honeybadger.notify_or_ignore(exception)
  end

  it "delivers an ignored exception when notifying manually" do
    set_public_env
    exception = build_exception
    stub_sender!
    notice = stub_notice!
    notice.stub(:ignore? => true)

    assert_sends(notice, :exception => exception)
    Honeybadger.notify(exception)
  end

  it "passes config to created notices" do
    exception = build_exception
    config_opts = { 'one' => 'two', 'three' => 'four' }
    stub_notice!
    stub_sender!
    Honeybadger.configuration = double('config', :merge => config_opts, :public? => true, :async? => false)

    Honeybadger::Notice.should_receive(:new).with(hash_including(config_opts))
    Honeybadger.notify(exception)
  end

  context "building notice JSON for an exception" do
    before(:each) do
      @params    = { :controller => "users", :action => "create" }
      @exception = build_exception
      @hash      = Honeybadger.build_lookup_hash_for(@exception, @params)
    end

    it "sets action" do
      expect(@hash[:action]).to eq @params[:action]
    end

    it "sets controller" do
      expect(@hash[:component]).to eq @params[:controller]
    end

    it "sets line number" do
      expect(@hash[:line_number]).to match /\d+/
    end

    it "sets file" do
      expect(@hash[:file]).to match /honeybadger\/rack_test\.rb$/
    end

    it "sets environment_name to production" do
      expect(@hash[:environment_name]).to eq 'production'
    end

    it "sets error class" do
      expect(@hash[:error_class]).to eq @exception.class.to_s
    end

    it "does not set file or line number with no backtrace" do
      @exception.stub(:backtrace).and_return([])

      @hash = Honeybadger.build_lookup_hash_for(@exception)

      @hash[:line_number].should be_nil
      @hash[:file].should be_nil
    end

    it "does not set action or controller when not provided" do
      @hash = Honeybadger.build_lookup_hash_for(@exception)

      @hash[:action].should be_nil
      @hash[:controller].should be_nil
    end

    context "when an exception that provides #original_exception is raised" do
      before(:each) do
        @exception.stub(:original_exception).and_return(begin
          raise OriginalException.new
        rescue Exception => e
          e
        end)
      end

      it "unwraps exceptions that provide #original_exception" do
        @hash = Honeybadger.build_lookup_hash_for(@exception)
        expect(@hash[:error_class]).to eq "OriginalException"
      end
    end

    context "when an exception that provides #continued_exception is raised" do
      before(:each) do
        @exception.stub(:continued_exception).and_return(begin
          raise ContinuedException.new
        rescue Exception => e
          e
        end)
      end

      it "unwraps exceptions that provide #continued_exception" do
        @hash = Honeybadger.build_lookup_hash_for(@exception)
        expect(@hash[:error_class]).to eq "ContinuedException"
      end
    end
  end
end
