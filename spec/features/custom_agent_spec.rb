feature "Creating a custom agent" do
  let(:crash_cmd) { "#{ FIXTURES_PATH.join('ruby_custom.rb') }" }

  it "reports the exception to Honeybadger" do
    cmd = run_command(crash_cmd)
    expect(cmd).not_to be_successfully_executed
    assert_notification(cmd.output, 'error' => {'class' => 'CustomHoneybadgerException', 'message' => 'Test message'})
  end
end
