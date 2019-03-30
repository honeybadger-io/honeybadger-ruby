feature "Rescuing exceptions in a rake task" do
  before do
    FileUtils.cp(FIXTURES_PATH.join('Rakefile'), current_dir)
    set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
    set_environment_variable('HONEYBADGER_LOGGING_LEVEL', 'DEBUG')
  end

  it "reports the exception to Honeybadger" do
    expect(run('rake honeybadger')).not_to be_successfully_executed
    assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Jim has left the building :('})
  end

  context "rake reporting is disabled" do
    before do
      set_environment_variable('HONEYBADGER_EXCEPTIONS_RESCUE_RAKE', 'false')
    end

    it "doesn't report the exception to Honeybadger" do
      expect(run('rake honeybadger')).not_to be_successfully_executed
      assert_no_notification
    end
  end

  context "shell is attached" do
    it "doesn't report the exception to Honeybadger" do
      expect(run('rake honeybadger_autodetect_from_terminal')).not_to be_successfully_executed
      assert_no_notification
    end

    context "rake reporting is enabled" do
      before do
        set_environment_variable('HONEYBADGER_EXCEPTIONS_RESCUE_RAKE', 'true')
      end

      it "reports the exception to Honeybadger" do
        expect(run('rake honeybadger_autodetect_from_terminal')).not_to be_successfully_executed
        assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Jim has left the building :('})
      end
    end
  end

  context "SignalException" do
    it "ignores SIGTERM" do
      expect(run('rake honeybadger_os_sigterm')).not_to be_successfully_executed
      assert_no_notification
    end

    it "reports non-SIGTERM" do
      expect(run('rake honeybadger_os_sighup')).not_to be_successfully_executed
      assert_notification('error' => {'class' => 'SignalException', 'message' => 'SignalException: SIGHUP'})
    end
  end
end
