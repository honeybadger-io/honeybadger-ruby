feature "Creating a custom agent" do
  let(:crash_cmd) { "ruby #{ FIXTURES_PATH.join('ruby_custom.rb') }" }

  it "reports the exception to Honeybadger" do
    expect(run(crash_cmd)).not_to be_successfully_executed
    assert_notification('error' => {'class' => 'CustomHoneybadgerException', 'message' => 'Test message'})
  end
end
