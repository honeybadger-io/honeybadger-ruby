require "honeybadger"

feature "Running the exec cli command" do
  before { set_environment_variable("HONEYBADGER_BACKEND", "debug") }

  it "quietly executes the requested command" do
    output = capture(:stdout) { Honeybadger::CLI.start(%w[exec --api-key=test-api-key ls]) }
    expect(output).to be_empty
  end

  context "when the options are invalid" do
    it "notifies the user" do
      output = capture(:stdout) do
        expect { Honeybadger::CLI.start(%w[exec --api-key= ls]) }.to raise_error(SystemExit)
      end
      expect(output).to match(/required.+api-key/i)
    end
  end

  context "when the command fails due to a non-zero exit code" do
    it "notifies Honeybadger of the failure" do
      output = capture(:stdout) do
        expect { Honeybadger::CLI.start(%w[exec --api-key=test-api-key this-command-should-not-exist]) }.to raise_error(SystemExit)
      end
      expect(output).to match(/failed.+this-command-should-not-exist/im)
      expect(output).to match(/Successfully notified Honeybadger/i)
    end
  end

  context "when the command fails due to standard error output" do
    it "notifies Honeybadger of the failure" do
      expect(run_command('honeybadger exec --api-key=test-api-key echo "test stderr" 1>&2')).to be_successfully_executed
      expect(all_output).to match(/failure/i)
      expect(all_output).to match(/test stderr/i)
      expect(all_output).to match(/Successfully notified Honeybadger/i)
    end
  end

  context "when Rails is not detected due to a missing environment.rb" do
    it "skips rails initialization without logging" do
      output = capture(:stdout) { Honeybadger::CLI.start(%w[exec --api-key=test-api-key --skip-rails-load ls]) }
      expect(output).to_not match(/Skipping Rails initialization/i)
    end
  end

  context "when Rails is detected via the presence of environment.rb" do
    before(:each) do
      @config_path = File.join(Dir.pwd, "config")
      FileUtils.mkdir_p(@config_path) unless File.exist?(@config_path)
      File.open(File.join(@config_path, "environment.rb"), "w")
    end

    after(:each) { FileUtils.rm_rf(@config_path) }

    it "skips rails initialization when true" do
      output = capture(:stdout) { Honeybadger::CLI.start(%w[exec --api-key=test-api-key --skip-rails-load ls]) }
      expect(output).to match(/Skipping Rails initialization/i)
    end

    it "does not skip rails initialization when false or not set" do
      output = capture(:stdout) { Honeybadger::CLI.start(%w[exec --api-key=test-api-key --skip-rails-load=false ls]) }
      expect(output).to_not match(/Skipping Rails initialization/i)

      output = capture(:stdout) { Honeybadger::CLI.start(%w[exec --api-key=test-api-key ls]) }
      expect(output).to_not match(/Skipping Rails initialization/i)
    end
  end
end
