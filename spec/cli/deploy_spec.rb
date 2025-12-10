require "honeybadger"

RSpec.describe "Running the deploy cli command", type: :aruba do
  before { set_environment_variable("HONEYBADGER_BACKEND", "debug") }

  it "notifies Honeybadger of the deploy" do
    output = capture(:stdout) { Honeybadger::CLI.start(%w[deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user]) }
    expect(output).to match(/Deploy notification complete/)
  end

  context "when the options are invalid" do
    it "notifies the user" do
      output = capture(:stdout) { expect { Honeybadger::CLI.start(%w[deploy --api-key= --environment=test-env --revision=test-rev --repository=test-repo --user=test-user]) }.to raise_error(SystemExit) }
      expect(output).to match(/required.+api-key/i)
    end
  end

  context "when there is a server error" do
    before { set_environment_variable("DEBUG_BACKEND_STATUS", "500") }

    it "notifies the user" do
      cmd = run_command("honeybadger deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user")
      expect(cmd).not_to be_successfully_executed
      expect(cmd.output).to match(/request failed/i)
    end
  end

  context "when Rails is not detected due to a missing environment.rb" do
    it "skips rails initialization without logging" do
      output = capture(:stdout) { Honeybadger::CLI.start(%w[deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user --skip-rails-load]) }
      expect(output).not_to match(/Skipping Rails initialization/i)
    end
  end

  context "when Rails is detected via the presence of environment.rb" do
    before do
      @aruba_dir = File.join(Dir.pwd, "tmp", "aruba")
      config_path = File.join(@aruba_dir, "config")
      Dir.mkdir(config_path) unless File.exist?(config_path)
      File.open(File.join(config_path, "environment.rb"), "w")
      @_previous_dir = Dir.pwd
      Dir.chdir(@aruba_dir)
    end

    after { Dir.chdir(@_previous_dir) }

    it "skips rails initialization when true" do
      output = capture(:stdout) { Honeybadger::CLI::Main.start(%w[deploy --skip-rails-load --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user]) }
      expect(output).to match(/Skipping Rails initialization/i)
    end

    it "does not skip rails initialization when false or not set" do
      output = capture(:stdout) { Honeybadger::CLI.start(%w[deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user --skip-rails-load=false]) }
      expect(output).to_not match(/Skipping Rails initialization/i)

      output = capture(:stdout) { Honeybadger::CLI.start(%w[deploy --api-key=test-api-key --environment=test-env --revision=test-rev --repository=test-repo --user=test-user]) }
      expect(output).to_not match(/Skipping Rails initialization/i)
    end
  end
end
