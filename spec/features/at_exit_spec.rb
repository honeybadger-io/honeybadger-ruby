feature "Rescuing exceptions at exit" do
  let(:crash_cmd) { "ruby #{ FIXTURES_PATH.join('ruby_crash.rb') }" }

  before do
    set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
    set_environment_variable('HONEYBADGER_LOGGING_LEVEL', 'DEBUG')
  end

  it "reports the exception to Honeybadger" do
    expect(run(crash_cmd)).not_to be_successfully_executed
    assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: badgers!'})
  end

  context "rake reporting is disabled" do
    before do
      set_environment_variable('HONEYBADGER_EXCEPTIONS_NOTIFY_AT_EXIT', 'false')
    end

    it "doesn't report the exception to Honeybadger" do
      expect(run(crash_cmd)).not_to be_successfully_executed
      assert_no_notification
    end
  end
end
