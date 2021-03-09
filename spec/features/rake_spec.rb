feature "Rescuing exceptions in a rake task" do
  before do
    FileUtils.cp(FIXTURES_PATH.join('Rakefile'), FEATURES_DIR)
    set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
    set_environment_variable('HONEYBADGER_LOGGING_LEVEL', 'DEBUG')
  end

  it "reports the exception to Honeybadger" do
    cmd = run_command('rake honeybadger')
    expect(cmd).not_to be_successfully_executed
    assert_notification(cmd.output, 'error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Jim has left the building :('})
  end

  context "rake reporting is disabled" do
    before do
      set_environment_variable('HONEYBADGER_EXCEPTIONS_RESCUE_RAKE', 'false')
    end

    it "doesn't report the exception to Honeybadger" do
      cmd = run_command('rake honeybadger')
      expect(cmd).not_to be_successfully_executed
      assert_no_notification(cmd.output)
    end
  end

  context "shell is attached" do
    it "doesn't report the exception to Honeybadger" do
      cmd = run_command('rake honeybadger_autodetect_from_terminal')
      expect(cmd).not_to be_successfully_executed
      assert_no_notification(cmd.output)
    end

    context "rake reporting is enabled" do
      before do
        set_environment_variable('HONEYBADGER_EXCEPTIONS_RESCUE_RAKE', 'true')
      end

      it "reports the exception to Honeybadger" do
        cmd = run_command('rake honeybadger_autodetect_from_terminal')
        expect(cmd).not_to be_successfully_executed
        assert_notification(cmd.output, 'error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Jim has left the building :('})
      end
    end
  end
end
