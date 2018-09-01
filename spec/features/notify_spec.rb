feature "Running the notify CLI command" do
  before do
    set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
    set_environment_variable('HONEYBADGER_LOGGING_LEVEL', 'DEBUG')
  end

  it "requires the --message flag" do
    expect(run('honeybadger notify')).to be_successfully_executed
    expect(all_output).to match('--message')
    assert_no_notification
  end

  context "with a message" do
    it "reports an exception with a default class" do
      expect(run('honeybadger notify --message "Test error message"')).to be_successfully_executed
      assert_notification('error' => {'class' => 'CLI Notification', 'message' => 'Test error message'})
    end

    it "overrides the class via --class flag" do
      expect(run('honeybadger notify --class "MyClass" --message "Test error message"')).to be_successfully_executed
      assert_notification('error' => {'class' => 'MyClass'})
    end

    it "uses configured API key" do
      expect(run('honeybadger notify --message "Test error message"')).to be_successfully_executed
      assert_notification('api_key' => 'asdf')
    end

    it "overrides the API key via --api-key flag" do
      expect(run('honeybadger notify --message "Test error message" --api-key my-key')).to be_successfully_executed
      assert_notification('api_key' => 'my-key')
    end
  end

  context "when Rails is not detected due to a missing environment.rb" do
    it "skips rails initialization without logging" do
      expect(run('honeybadger notify --message "Test error message" --skip-rails-load')).to be_successfully_executed
      expect(all_output).to_not match(/Skipping Rails initialization/i)
    end
  end

  context "when Rails is detected via the presence of environment.rb" do
    before do
      config_path = File.join(Dir.pwd, 'tmp', 'features', 'config')
      Dir.mkdir(config_path) unless File.exists?(config_path)
      File.open(File.join(config_path, 'environment.rb'), 'w')
    end

    it "skips rails initialization when true" do
      expect(run('honeybadger notify --message "Test error message" --skip-rails-load')).to be_successfully_executed
      expect(all_output).to match(/Skipping Rails initialization/i)
    end

    it "does not skip rails initialization when false or not set" do
      expect(run('honeybadger notify --message "Test error message" --skip-rails-load=false')).to be_successfully_executed
      expect(all_output).to_not match(/Skipping Rails initialization/i)

      expect(run('honeybadger notify --message "Test error message"')).to be_successfully_executed
      expect(all_output).to_not match(/Skipping Rails initialization/i)
    end
  end
end
