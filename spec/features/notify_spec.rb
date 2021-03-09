feature "Running the notify CLI command" do
  let(:error_message) { "Test error message" }
  before do
    set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
    set_environment_variable('HONEYBADGER_LOGGING_LEVEL', 'DEBUG')
  end

  it "requires the --message flag" do
    output = capture(:stderr) { Honeybadger::CLI.start(%w[notify]) }
    expect(output).to match('--message')
    assert_no_notification(output)
  end

  context "with a message" do
    it "reports an exception with a default class" do
      cmd = run_command("honeybadger notify --message '#{error_message}'")
      expect(cmd).to be_successfully_executed
      assert_notification(cmd.output, 'error' => {'class' => 'CLI Notification', 'message' => 'Test error message'})
    end

    it "overrides the class via --class flag" do
      cmd = run_command("honeybadger notify --class 'MyClass' --message '#{error_message}'")
      expect(cmd).to be_successfully_executed
      assert_notification(cmd.output, 'error' => {'class' => 'MyClass'})
    end

    it "uses configured API key" do
      cmd = run_command("honeybadger notify --message '#{error_message}'")
      expect(cmd).to be_successfully_executed
      assert_notification(cmd.output, 'api_key' => 'asdf')
    end

    it "overrides the API key via --api-key flag" do
      cmd = run_command("honeybadger notify --message '#{error_message}' --api-key my-key")
      expect(cmd).to be_successfully_executed
      assert_notification(cmd.output, 'api_key' => 'my-key')
    end
  end

  context "when Rails is not detected due to a missing environment.rb" do
    it "skips rails initialization without logging" do
      output = capture(:stdout) { Honeybadger::CLI.start(%W[notify --message #{error_message} --skip-rails-load]) }
      expect(output).to_not match(/Skipping Rails initialization/i)
    end
  end

  context "when Rails is detected via the presence of environment.rb" do
    before do
      @config_path = File.join(Dir.pwd, 'config')
      FileUtils.mkdir_p(@config_path) unless File.exists?(@config_path)
      File.open(File.join(@config_path, 'environment.rb'), 'w')
    end

    after do
      FileUtils.rm_rf(@config_path)
    end

    it "skips rails initialization when true" do
      cmd = capture(:stdout) { Honeybadger::CLI.start(%W[notify --message #{error_message} --skip-rails-load]) }
      expect(cmd).to match(/Skipping Rails initialization/i)
    end

    it "does not skip rails initialization when false or not set" do
      output = capture(:stdout) { Honeybadger::CLI.start(%W[notify --message #{error_message} --skip-rails-load=false]) }
      expect(output).to_not match(/Skipping Rails initialization/i)

      ouput = capture(:stdout) { Honeybadger::CLI.start(%W[notify --message #{error_message}]) }
      expect(output).to_not match(/Skipping Rails initialization/i)
    end
  end
end
