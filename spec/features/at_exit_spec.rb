feature "Rescuing exceptions at exit" do
  let(:crash_cmd) { "ruby #{ FIXTURES_PATH.join('ruby_crash.rb') }"}

  def custom_crash_cmd(crash_type)
    "ruby #{ FIXTURES_PATH.join('ruby_custom_crash.rb') } #{ crash_type }"
  end

  before do
    set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
    set_environment_variable('HONEYBADGER_LOGGING_LEVEL', 'DEBUG')
  end

  it "reports the exception to Honeybadger" do
    cmd = run_command(crash_cmd)
    expect(cmd).not_to be_successfully_executed
    assert_notification(cmd.output, 'error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: badgers!'})
  end

  it "ignores SystemExit" do
    cmd = run_command(custom_crash_cmd("system_exit"))
    expect(cmd).not_to be_successfully_executed
    assert_no_notification(cmd.output)
  end

  it "ignores SignalException of type SIGTERM" do
    cmd = run_command(custom_crash_cmd("sigterm"))
    expect(cmd).not_to be_successfully_executed
    assert_no_notification(cmd.output)
  end

  it "reports SignalException of type other than SIGTERM" do
    cmd = run_command(custom_crash_cmd("hup"))
    expect(cmd).not_to be_successfully_executed
    assert_notification(cmd.output, 'error' => {'class' => 'SignalException', 'message' => 'SignalException: SIGHUP'})
  end

  context "at_exit is disabled" do
    before do
      set_environment_variable('HONEYBADGER_EXCEPTIONS_NOTIFY_AT_EXIT', 'false')
    end

    it "doesn't report the exception to Honeybadger" do
      cmd = run_command(crash_cmd)
      expect(cmd).not_to be_successfully_executed
      assert_no_notification(cmd.output)
    end
  end
end
